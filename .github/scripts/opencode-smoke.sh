#!/usr/bin/env bash
# Proves the opencode on this runner can answer a prompt at all, before the
# week's bump relies on it.
#
# Worth its own step because the fix stage is the only thing that runs
# opencode and it only runs after a build has already failed -- so a broken
# opencode is found at the worst possible moment, as an hour of nothing. It
# got there once: nixpkgs shipped 1.18.30, which throws in
# SystemPrompt.environment before any request leaves the machine, and the
# bump that introduced it passed every gate. No build can catch that; the
# package builds fine and dies at runtime on the first prompt.
#
# Runs in an empty directory, with --pure and no MCP: what is under test is
# the binary, not this repo's AGENTS.md or a server that may not be on the
# runner's PATH yet.
#
# Exit 0  opencode answered
# Exit 1  opencode did not answer -- it is the suspect
# Exit 2  the model server did not answer -- opencode is not the suspect
#
# Nothing here fails the run; the caller decides what a failure means.
set -uo pipefail

CONFIG="${OPENCODE_SMOKE_CONFIG:-.github/opencode/opencode.json}"
OLLAMA_URL="${OLLAMA_URL:-http://127.0.0.1:11434}"
# Small on purpose: this asks whether opencode can complete one round trip,
# and the crash it guards against is provider-independent. Loading the 27B
# to find that out would cost minutes and evict whatever else holds the GPU.
SMOKE_MODEL="${SMOKE_MODEL:-ollama/team-small:latest}"
# Generous, because a cold run pays for two things at once: opencode
# fetching its provider package, and the server loading a model that may
# have been evicted. Neither says anything about whether opencode works.
# Measured at ~5 minutes on a cold cache with the GPU busy, and the runners
# are ephemeral, so every week is a cold cache.
TIMEOUT="${OPENCODE_SMOKE_TIMEOUT:-420}"
# opencode fetches its provider packages into XDG_CACHE_HOME on first use.
# Left inside the scratch HOME that is an npm fetch on every run; point this
# at the cache the fix agent will use and the test warms it instead.
CACHE_HOME="${OPENCODE_SMOKE_CACHE:-}"
# Distinctive enough that it cannot appear by chance in a refusal or an
# error banner, which is what a laxer check would end up matching.
SENTINEL="opencode-smoke-ok"

command -v opencode >/dev/null 2>&1 || {
  echo "opencode-smoke: opencode is not on PATH" >&2
  exit 1
}

# curl is optional on this runner (see the workflow's preflight), and its
# absence is not opencode's fault either.
if ! command -v curl >/dev/null 2>&1; then
  echo "opencode-smoke: curl is not on PATH; opencode untested" >&2
  exit 2
fi

if ! curl -fsS --max-time 10 "$OLLAMA_URL/api/tags" >/dev/null 2>&1; then
  echo "opencode-smoke: no model server at $OLLAMA_URL; opencode untested" >&2
  exit 2
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/home/.config/opencode" "$work/empty"
[ -n "$CACHE_HOME" ] || CACHE_HOME="$work/home/.cache"
mkdir -p "$CACHE_HOME"

# The MCP server is dropped rather than exercised: it is optional to the fix
# agent too (see the workflow's preflight), and its absence must not read as
# opencode being broken.
jq 'del(.mcp)' "$CONFIG" > "$work/home/.config/opencode/opencode.json" || {
  echo "opencode-smoke: could not read $CONFIG" >&2
  exit 1
}

out="$work/out.txt"
HOME="$work/home" \
XDG_CONFIG_HOME="$work/home/.config" \
XDG_CACHE_HOME="$CACHE_HOME" \
OPENCODE_CONFIG="$work/home/.config/opencode/opencode.json" \
  timeout --signal=TERM --kill-after=15s "${TIMEOUT}s" \
  opencode run --pure --dir "$work/empty" -m "$SMOKE_MODEL" \
  "Reply with exactly this word and nothing else: $SENTINEL" \
  > "$out" 2>&1
rc=$?

if grep -qF "$SENTINEL" "$out"; then
  echo "opencode-smoke: $(opencode --version) answered on $SMOKE_MODEL"
  exit 0
fi

{
  if [ "$rc" = 124 ] || [ "$rc" = 137 ]; then
    echo "opencode-smoke: no answer within ${TIMEOUT}s from $(opencode --version)"
  else
    echo "opencode-smoke: $(opencode --version) exited $rc without answering"
  fi
  echo "--- last 40 lines ---"
  tail -n 40 "$out"
} >&2
exit 1
