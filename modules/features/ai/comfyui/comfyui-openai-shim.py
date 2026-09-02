#!/usr/bin/env python3
"""OpenAI images API in front of ComfyUI.

ComfyUI speaks POST /prompt with a workflow graph; clients like Odysseus speak
POST /v1/images/generations. This translates between them.

One workflow file per exposed model: <name>.json in --workflows, in ComfyUI's
*API* format ("Save (API Format)" in the web UI, not the editor format).
Placeholders are substituted structurally after the JSON is parsed, so no
escaping concerns:

    "%PROMPT%"  "%NEGATIVE%"  "%SEED%"  "%WIDTH%"  "%HEIGHT%"  "%BATCH%"

ComfyUI caches a checkpoint in VRAM indefinitely after a run, which starves
anything else on the card. --free-after-run hands it back via POST /free, the
same trade Ollama's keep_alive makes.

Stdlib only, on purpose -- it keeps the closure to a Python interpreter.
"""

import argparse
import base64
import json
import random
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

DEFAULT_SIZE = (1024, 1024)
MAX_BATCH = 8


def _http(method, url, body=None, timeout=30):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    if data:
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def _substitute(node_inputs, values):
    """Replace placeholder strings anywhere in a node's inputs."""
    out = {}
    for key, value in node_inputs.items():
        out[key] = values[value] if isinstance(value, str) and value in values else value
    return out


def parse_size(raw):
    """'1024x1024' -> (1024, 1024). ComfyUI wants multiples of 8."""
    if not raw or raw == "auto":
        return DEFAULT_SIZE
    try:
        w, h = (int(x) for x in str(raw).lower().split("x", 1))
    except ValueError:
        return DEFAULT_SIZE
    if not (64 <= w <= 4096 and 64 <= h <= 4096):
        return DEFAULT_SIZE
    return w - w % 8, h - h % 8


class Comfy:
    def __init__(self, base, timeout):
        self.base = base.rstrip("/")
        self.timeout = timeout

    def submit(self, graph):
        body = {"prompt": graph, "client_id": "comfyui-openai-shim"}
        try:
            return json.loads(_http("POST", f"{self.base}/prompt", body))["prompt_id"]
        except urllib.error.HTTPError as e:
            # ComfyUI validates the graph and reports which node failed. Pass
            # that through -- it is the only useful thing in a 400 here.
            detail = e.read().decode("utf-8", "replace")[:800]
            raise RuntimeError(f"ComfyUI rejected the workflow: {detail}") from None

    def wait(self, prompt_id):
        """Poll /history until the run leaves the queue."""
        deadline = time.monotonic() + self.timeout
        while time.monotonic() < deadline:
            raw = json.loads(_http("GET", f"{self.base}/history/{prompt_id}"))
            entry = raw.get(prompt_id)
            if entry:
                status = entry.get("status", {})
                if status.get("status_str") == "error":
                    raise RuntimeError(f"ComfyUI run failed: {json.dumps(status)[:800]}")
                if status.get("completed") or entry.get("outputs"):
                    return entry.get("outputs", {})
            time.sleep(1.0)
        raise RuntimeError(f"ComfyUI did not finish within {self.timeout}s")

    def free(self):
        """Release VRAM. Best-effort: the images are already on disk."""
        try:
            _http("POST", f"{self.base}/free",
                  {"unload_models": True, "free_memory": True}, timeout=30)
        except (urllib.error.URLError, OSError, ValueError) as e:
            sys.stderr.write(f"warning: /free failed, VRAM still held: {e}\n")

    def fetch(self, image):
        query = urllib.parse.urlencode({
            "filename": image["filename"],
            "subfolder": image.get("subfolder", ""),
            "type": image.get("type", "output"),
        })
        return _http("GET", f"{self.base}/view?{query}", timeout=self.timeout)


class Handler(BaseHTTPRequestHandler):
    server_version = "comfyui-openai-shim"
    workflows = {}
    comfy = None
    free_after_run = True
    # ComfyUI executes one graph at a time anyway, and serialising here is what
    # keeps a /free for one request from unloading the model under another.
    lock = threading.Lock()

    def log_message(self, fmt, *args):
        sys.stderr.write("%s %s\n" % (self.address_string(), fmt % args))

    def _send(self, code, payload):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _fail(self, code, message):
        self._send(code, {"error": {"message": message, "type": "invalid_request_error"}})

    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path.rstrip("/")
        if path in ("/v1/models", "/models"):
            self._send(200, {
                "object": "list",
                "data": [
                    {"id": name, "object": "model", "owned_by": "comfyui"}
                    for name in sorted(self.workflows)
                ],
            })
        elif path == "/health":
            self._send(200, {"status": "ok", "models": sorted(self.workflows)})
        else:
            self._fail(404, f"Unknown path {path}")

    def do_POST(self):
        path = urllib.parse.urlparse(self.path).path.rstrip("/")
        if path not in ("/v1/images/generations", "/images/generations"):
            self._fail(404, f"Unknown path {path}")
            return
        try:
            length = int(self.headers.get("Content-Length") or 0)
            body = json.loads(self.rfile.read(length) or b"{}")
        except (ValueError, TypeError):
            self._fail(400, "Body is not valid JSON")
            return

        prompt = (body.get("prompt") or "").strip()
        if not prompt:
            self._fail(400, "prompt is required")
            return

        model = body.get("model") or ""
        workflow = self.workflows.get(model)
        if workflow is None:
            # Odysseus resolves a model id from the endpoint's /v1/models list,
            # but its own picker may still send an alias. One workflow means
            # there is no ambiguity to resolve.
            if len(self.workflows) == 1:
                model, workflow = next(iter(self.workflows.items()))
            else:
                self._fail(404, f"No workflow for model '{model}'. Have: {sorted(self.workflows)}")
                return

        width, height = parse_size(body.get("size"))
        batch = max(1, min(MAX_BATCH, int(body.get("n") or 1)))
        values = {
            "%PROMPT%": prompt,
            "%NEGATIVE%": body.get("negative_prompt") or "",
            "%SEED%": random.randint(0, 2**63 - 1),
            "%WIDTH%": width,
            "%HEIGHT%": height,
            "%BATCH%": batch,
        }
        graph = {
            node_id: {**node, "inputs": _substitute(node.get("inputs", {}), values)}
            for node_id, node in workflow.items()
        }

        try:
            with self.lock:
                try:
                    outputs = self.comfy.wait(self.comfy.submit(graph))
                    images = [img for node in outputs.values() for img in node.get("images", [])]
                    # SaveImage also emits temp previews; saved outputs are the result.
                    saved = [i for i in images if i.get("type") == "output"] or images
                    if not saved:
                        raise RuntimeError(
                            "ComfyUI returned no images -- does the workflow end in SaveImage?"
                        )
                    data = [
                        {"b64_json": base64.b64encode(self.comfy.fetch(i)).decode()}
                        for i in saved[:batch]
                    ]
                finally:
                    # In `finally` because a run that failed after loading the
                    # checkpoint is holding just as much VRAM as one that worked.
                    if self.free_after_run:
                        self.comfy.free()
        except RuntimeError as e:
            self._fail(502, str(e))
            return
        except (urllib.error.URLError, OSError) as e:
            self._fail(502, f"Cannot reach ComfyUI at {self.comfy.base}: {e}")
            return

        self._send(200, {"created": int(time.time()), "data": data, "model": model})


def load_workflows(directory):
    workflows = {}
    for path in sorted(Path(directory).glob("*.json")):
        try:
            workflows[path.stem] = json.loads(path.read_text())
        except (OSError, ValueError) as e:
            sys.stderr.write(f"skipping {path}: {e}\n")
    return workflows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--listen", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=7860)
    ap.add_argument("--comfyui", default="http://127.0.0.1:8188")
    ap.add_argument("--workflows", required=True)
    ap.add_argument("--timeout", type=int, default=600)
    ap.add_argument("--free-after-run", dest="free_after_run", action="store_true", default=True)
    ap.add_argument("--no-free-after-run", dest="free_after_run", action="store_false")
    args = ap.parse_args()

    Handler.workflows = load_workflows(args.workflows)
    Handler.comfy = Comfy(args.comfyui, args.timeout)
    Handler.free_after_run = args.free_after_run
    if not Handler.workflows:
        sys.stderr.write(f"no workflows in {args.workflows}\n")
        return 1

    sys.stderr.write(
        f"serving {sorted(Handler.workflows)} on {args.listen}:{args.port} -> {args.comfyui}\n"
    )
    ThreadingHTTPServer((args.listen, args.port), Handler).serve_forever()
    return 0


if __name__ == "__main__":
    sys.exit(main())
