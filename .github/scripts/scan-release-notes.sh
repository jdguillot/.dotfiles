#!/usr/bin/env bash
# Asks the local model for a high-level overview of what landed in this
# week's flake inputs, grouped by the modules in this repo that consume
# them. Distinct from scan-verdict.sh in purpose: verdict judges each
# source on its own merits and returns holds + a note about the staged
# work that landed this week; this one reads the same upstream digest and
# shapes it into notes for a human doing a first read of the pull request.
#
# Why a separate call rather than extending the verdict: the verdict is
# constrained-decoded to a schema whose `holds.name` enum is over the
# update-target source names, which is the right shape for a machine to
# hold back; the release notes are free-form markdown grouped by this
# repo's own module names, which is a different document and a different
# failure mode. Keeping the two calls independent means a degraded model
# degrades one side and not the other.
#
# Fails open, the same way scan-verdict does: the notes are advisory and
# the build gate downstream is the actual safety net, so an unreachable
# model must not stall the week's bump.
set -euo pipefail

OUT_DIR="${OUT_DIR:-upstream-signal}"
OLLAMA_URL="${OLLAMA_URL:-http://127.0.0.1:11434}"
NOTES_MODEL="${NOTES_MODEL:-qwen3.8:27b-q4_K_M}"
NUM_CTX="${NUM_CTX:-262144}"

digest="$OUT_DIR/digest.md"
notes="$OUT_DIR/release-notes.md"

[ -s "$digest" ] || { echo "notes: nothing to summarize (no digest)" >&2; exit 0; }
curl -fsS --max-time 10 "$OLLAMA_URL/api/tags" >/dev/null 2>&1 \
  || { echo "notes: ollama unreachable -- skipping" >&2; exit 0; }

system_prompt="$(cat .github/opencode/release-notes-prompt.md)"

request=$(jq -n \
  --arg model "$NOTES_MODEL" \
  --arg system "$system_prompt" \
  --arg hosts "$(cat hosts/default.nix)" \
  --rawfile digest "$digest" \
  --argjson num_ctx "$NUM_CTX" '{
    model: $model,
    stream: false,
    options: { temperature: 0, num_ctx: $num_ctx },
    messages: [
      { role: "system", content: $system },
      { role: "user", content:
          ("## The machines this feeds\n\n```nix\n" + $hosts + "\n```\n\n"
           + "## Upstream changes\n\n" + $digest) }
    ]
  }')

response=$(curl -fsS --max-time 3600 "$OLLAMA_URL/api/chat" \
  -H 'Content-Type: application/json' -d "$request") \
  || { echo "notes: request failed -- skipping" >&2; exit 0; }

content=$(jq -r '.message.content // empty' <<<"$response")
[ -n "$content" ] || { echo "notes: empty completion -- skipping" >&2; exit 0; }
printf '%s\n\n' "$content" > "$notes"

echo "notes: $(wc -c < "$notes") bytes of release notes in $notes"
