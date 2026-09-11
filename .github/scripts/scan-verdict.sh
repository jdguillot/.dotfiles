#!/usr/bin/env bash
# Asks the local model whether any pinned input should sit this week out,
# given the digest collect-upstream-signal.sh built.
#
# Straight curl against Ollama rather than an agent: the job here is one
# judgement over one bounded document, and Ollama's JSON-schema constrained
# decoding makes the answer parseable by construction. An agent would add a
# bun runtime, an npm fetch and a session database to a step that needs none
# of it. The fix stage, which really does have to edit files, uses opencode.
#
# Fails open. A hold list is advice; `nix flake check` and the per-host
# builds are the actual gate, so an unreachable model must not stall the
# weekly bump.
set -euo pipefail

OUT_DIR="${OUT_DIR:-upstream-signal}"
OLLAMA_URL="${OLLAMA_URL:-http://127.0.0.1:11434}"
SCAN_MODEL="${SCAN_MODEL:-qwen3.8:27b-q4_K_M}"
NUM_CTX="${NUM_CTX:-262144}"

digest="$OUT_DIR/digest.md"
sources="$OUT_DIR/sources.json"
ledger="$OUT_DIR/ledger.json"
staged="${STAGED_REPORT:-staging-report}/staged-commits.txt"
verdict="$OUT_DIR/verdict.json"

fail_open() {
  echo "scan: $1 -- proceeding with no holds" >&2
  jq -n --arg s "$1" '{
    holds: [],
    summary: ("Scan unavailable: " + $s),
    staged_notes: "Scan unavailable.",
    degraded: true
  }' > "$verdict"
  exit 0
}

[ -s "$digest" ] || fail_open "no digest to read"
# The staged-commits file is empty when no `staging/*` branch merged into
# this tree; the LLM prompt handles both cases. Not a failure either way.
if [ ! -f "$staged" ]; then
  : > "$staged"
fi
curl -fsS --max-time 10 "$OLLAMA_URL/api/tags" >/dev/null 2>&1 || fail_open "ollama unreachable at $OLLAMA_URL"

# Named inputs only: an enum keeps the model from inventing a source name
# that the update step would then silently fail to hold back.
names=$(jq -c '[.[].name]' "$sources")

# What previous runs held and why. Every run is otherwise the first one it
# has ever had, so without this a hold either renews forever on a reason
# nobody re-reads, or lapses silently because this week's evidence window
# starts after the breakage.
[ -s "$ledger" ] || echo '{"holds":{}}' > "$ledger"
standing=$(jq -r '
  if (.holds | length) == 0 then "None. Nothing is currently held."
  else ( .holds | to_entries[] | .value as $v |
    "- `\(.key)`: held \($v.weeks) week(s), since \($v.first_seen). Reason on record: \($v.reason)."
    + (if ($v.upstream | length) > 0
       then " Tracking: " + ([$v.upstream[] | "\(.url) [\(.state)]"] | join(", ")) + "."
       else " Nothing is being tracked upstream for it." end)
    + (if $v.stalled_weeks >= 2
       then " Nothing has moved upstream on it for \($v.stalled_weeks) week(s)."
       else "" end)
    + (if ($v.recommendation.standing // "none") != "none"
       then " Upstream recommends (\($v.recommendation.standing)): \($v.recommendation.recommendation)"
       else "" end) )
  end' "$ledger")

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
    summary: { type: "string" },
    staged_notes: { type: "string" }
  },
  required: ["holds", "summary", "staged_notes"]
}')

request=$(jq -n \
  --arg model "$SCAN_MODEL" \
  --arg system "$(cat .github/opencode/scan-prompt.md)" \
  --arg hosts "$(cat hosts/default.nix)" \
  --rawfile digest "$digest" \
  --rawfile staged "$staged" \
  --arg standing "$standing" \
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
           + (if $staged == ""
                 then "## Staged branches\n"
                      + "No staged work was merged into this tree this week.\n\n"
                      else "## Staged branches (already merged into this tree)\n"
                           + $staged + "\n\n"
                      end)
           + "## Standing holds from previous runs\n\n" + $standing + "\n\n"
           + "## Upstream changes\n\n" + $digest) }
    ]
  }')

response=$(curl -fsS --max-time 3600 "$OLLAMA_URL/api/chat" \
  -H 'Content-Type: application/json' -d "$request") || fail_open "ollama request failed"

content=$(jq -r '.message.content // empty' <<<"$response")
[ -n "$content" ] || fail_open "empty completion"
jq -e . >/dev/null 2>&1 <<<"$content" || fail_open "completion was not JSON"

# Constrained decoding guarantees the shape, not the truth of it. Drop any
# hold naming a source that is not actually in the update set, and default
# staged_notes to an empty string if the model omitted it (schema-required,
# but a misbehaving decoding can produce a missing key; never a crash).
jq --argjson names "$names" \
  '{ holds: [.holds[] | select(.name as $n | $names | index($n))],
     summary: (.summary // ""),
     staged_notes: (.staged_notes // ""),
     degraded: false }' <<<"$content" > "$verdict"

echo "scan: $(jq '.holds | length' "$verdict") hold(s) of $(jq 'length' "$sources") sources"
jq -r '.holds[] | "  hold \(.name): \(.reason)"' "$verdict"
