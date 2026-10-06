#!/usr/bin/env bash
# Asks the local model what the week's container bumps mean for these
# hosts, given the digest collect-container-signal.sh built: which to hold
# back, what to watch for on each, what to do before deploying it, and the
# features worth knowing about.
#
# Shaped like scan-verdict.sh -- one curl against Ollama with a JSON schema,
# no agent -- and it fails open the same way: the notes are advisory and an
# unreachable model must not cost the week its bump. The difference from the
# nix scan is that there is no build gate behind this one. A bumped image
# tag renders into a compose file that evaluates and builds exactly as
# before; the first thing that can fail is the container on the host after
# the merge. So the schema asks for a `before_deploying` step per container
# as well as the holds, and the pull request prints it.
#
# One call, not two: the document is a handful of images, and the holds and
# the notes come from the same reading of the same release notes.
set -euo pipefail

OUT_DIR="${OUT_DIR:-upstream-signal}"
OLLAMA_URL="${OLLAMA_URL:-http://127.0.0.1:11434}"
SCAN_MODEL="${SCAN_MODEL:-qwen3.8:27b-q4_K_M}"
NUM_CTX="${NUM_CTX:-262144}"

digest="$OUT_DIR/digest-containers.md"
containers="$OUT_DIR/containers.json"
verdict="$OUT_DIR/containers-verdict.json"

fail_open() {
  echo "containers: $1 -- proceeding with no holds and no notes" >&2
  jq -n --arg s "$1" '{
    holds: [],
    containers: [],
    summary: ("Container scan unavailable: " + $s),
    degraded: true
  }' > "$verdict"
  exit 0
}

[ -s "$containers" ] || fail_open "no containers.json to read"
[ -s "$digest" ] || fail_open "no digest to read"

# Only the entries that move are the model's to judge; an unchanged image
# has nothing to hold and nothing to note. A week where nothing moves
# needs no model at all.
names=$(jq -c '[.[] | select(.state == "changed") | .name]' "$containers")
if [ "$(jq 'length' <<<"$names")" -eq 0 ]; then
  jq -n '{ holds: [], containers: [], summary: "No pinned container image moves this week.", degraded: false }' > "$verdict"
  echo "containers: nothing changed; the model was not asked"
  exit 0
fi

curl -fsS --max-time 10 "$OLLAMA_URL/api/tags" >/dev/null 2>&1 || fail_open "ollama unreachable at $OLLAMA_URL"

schema=$(jq -n --argjson names "$names" '{
  type: "object",
  properties: {
    holds: {
      type: "array",
      items: {
        type: "object",
        properties: {
          name: { type: "string", enum: $names },
          reason: { type: "string" },
          evidence: { type: "string" }
        },
        required: ["name", "reason", "evidence"]
      }
    },
    containers: {
      type: "array",
      items: {
        type: "object",
        properties: {
          name: { type: "string", enum: $names },
          watch_for: { type: "string" },
          before_deploying: { type: "string" },
          highlights: { type: "string" }
        },
        required: ["name", "watch_for", "before_deploying", "highlights"]
      }
    },
    summary: { type: "string" }
  },
  required: ["holds", "containers", "summary"]
}')

request=$(jq -n \
  --arg model "$SCAN_MODEL" \
  --arg system "$(cat .github/opencode/container-prompt.md)" \
  --arg hosts "$(cat hosts/default.nix)" \
  --rawfile digest "$digest" \
  --argjson schema "$schema" \
  --argjson num_ctx "$NUM_CTX" '{
    model: $model,
    stream: false,
    format: $schema,
    options: { temperature: 0, num_ctx: $num_ctx },
    messages: [
      { role: "system", content: $system },
      { role: "user", content:
          ("## The machines this feeds\n\n```nix\n" + $hosts + "\n```\n\n"
           + "## The container images\n\n" + $digest) }
    ]
  }')

response=$(curl -fsS --max-time 3600 "$OLLAMA_URL/api/chat" \
  -H 'Content-Type: application/json' -d "$request") || fail_open "ollama request failed"

content=$(jq -r '.message.content // empty' <<<"$response")
[ -n "$content" ] || fail_open "empty completion"
jq -e . >/dev/null 2>&1 <<<"$content" || fail_open "completion was not JSON"

# Constrained decoding guarantees the shape, not the names: drop anything
# naming an entry that is not moving this week, and never crash on a key
# a misbehaving decode left out.
jq --argjson names "$names" \
  '{ holds: [ (.holds // [])[] | select(.name as $n | $names | index($n)) ],
     containers: ([ (.containers // [])[] | select(.name as $n | $names | index($n)) ] | unique_by(.name)),
     summary: (.summary // ""),
     degraded: false }' <<<"$content" > "$verdict"

echo "containers: $(jq '.holds | length' "$verdict") hold(s) of $(jq 'length' <<<"$names") moving; notes for $(jq '.containers | length' "$verdict")"
jq -r '.holds[] | "  hold \(.name): \(.reason)"' "$verdict"
