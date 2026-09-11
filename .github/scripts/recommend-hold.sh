#!/usr/bin/env bash
# What the people in a held input's upstream threads recommend doing about
# it. Called by hold-ledger.sh record for every hold that tracks an issue or
# PR; the answer is kept in the ledger and printed in the pull request.
#
# Shaped like scan-verdict.sh: bounded evidence from a deterministic
# collector (collect-thread-signal.sh), one schema-constrained call to the
# local model, and fail open -- no answer means no recommendation line this
# week, never a failed ledger record.
#
# Usage: recommend-hold.sh <name> <reason> <url>...
#   prints {"recommendation", "standing", "basis"} as one line of JSON, or
#   nothing. The evidence it read is left in $OUT_DIR/threads/<name>.md.
set -euo pipefail

name="${1:?usage: recommend-hold.sh <name> <reason> <url>...}"
reason="${2:?usage: recommend-hold.sh <name> <reason> <url>...}"
shift 2
[ $# -gt 0 ] || exit 0

OUT_DIR="${OUT_DIR:-upstream-signal}"
OLLAMA_URL="${OLLAMA_URL:-http://127.0.0.1:11434}"
SCAN_MODEL="${SCAN_MODEL:-qwen3.8:27b-q4_K_M}"
# collect-thread-signal.sh caps its output at 60k characters, well inside.
NUM_CTX="${NUM_CTX:-65536}"

skip() {
  echo "recommend-hold: $name: $1 -- no recommendation this week" >&2
  exit 0
}

mkdir -p "$OUT_DIR/threads"
evidence="$OUT_DIR/threads/$name.md"
.github/scripts/collect-thread-signal.sh "$@" > "$evidence" || skip "collecting the discussion failed"
[ -s "$evidence" ] || skip "no discussion to read"
curl -fsS --max-time 10 "$OLLAMA_URL/api/tags" >/dev/null 2>&1 || skip "ollama unreachable at $OLLAMA_URL"

schema=$(jq -n '{
  type: "object",
  properties: {
    recommendation: { type: "string" },
    standing: { type: "string",
                enum: ["maintainer-endorsed", "linked-outcome", "community-consensus",
                       "individual-suggestion", "none"] },
    basis: { type: "string" }
  },
  required: ["recommendation", "standing", "basis"]
}')

request=$(jq -n \
  --arg model "$SCAN_MODEL" \
  --arg system "$(cat .github/opencode/recommendation-prompt.md)" \
  --arg name "$name" \
  --arg reason "$reason" \
  --rawfile evidence "$evidence" \
  --argjson schema "$schema" \
  --argjson num_ctx "$NUM_CTX" '{
    model: $model,
    stream: false,
    format: $schema,
    options: { temperature: 0, num_ctx: $num_ctx },
    messages: [
      { role: "system", content: $system },
      { role: "user", content:
          ("## The held input\n\n`" + $name + "` is held because: " + $reason + "\n\n"
           + "## The upstream discussion\n\n" + $evidence) }
    ]
  }')

response=$(curl -fsS --max-time 1800 "$OLLAMA_URL/api/chat" \
  -H 'Content-Type: application/json' -d "$request") || skip "ollama request failed"

content=$(jq -r '.message.content // empty' <<<"$response")
[ -n "$content" ] || skip "empty completion"
jq -e '(.recommendation | type) == "string" and (.recommendation | length) > 0' \
  >/dev/null 2>&1 <<<"$content" || skip "completion was not a usable answer"

# One line each: the ledger report prints them as list items.
jq -c '{ recommendation: (.recommendation | gsub("\n"; " ")),
         standing: (.standing // "none"),
         basis: ((.basis // "") | gsub("\n"; " ")) }' <<<"$content"
