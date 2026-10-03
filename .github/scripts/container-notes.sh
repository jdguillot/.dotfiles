#!/usr/bin/env bash
# Renders the container section of the job summary and the pull request
# body from the collector's table, the model's verdict and -- in the pull
# request -- what apply-container-updates.sh actually did. One renderer for
# both, so the preview in the scan summary and the section in the pull
# request cannot drift apart.
#
# Usage: container-notes.sh <containers.json> <containers-verdict.json> [<containers-applied.json>]
# Markdown on stdout. Upstream URLs pass through; the pull request body is
# sanitised as a whole by sanitize-refs.sh.
set -euo pipefail

containers="${1:?usage: container-notes.sh <containers.json> <verdict.json> [<applied.json>]}"
verdict="${2:?usage: container-notes.sh <containers.json> <verdict.json> [<applied.json>]}"
applied="${3:-}"

[ -s "$containers" ] || exit 0
[ -s "$verdict" ] || verdict=<(echo '{"holds":[],"containers":[],"summary":""}')

summary=$(jq -r '.summary // ""' "$verdict")
[ -z "$summary" ] || { echo "$summary"; echo ""; }

if [ -n "$applied" ] && [ -s "$applied" ]; then
  if [ "$(jq 'length' "$applied")" -gt 0 ]; then
    echo "| Container | Image | From | To | Outcome |"
    echo "|---|---|---|---|---|"
    jq -r '.[] | "| `\(.name)` | `\(.image)` | \(.from) | \(.to) | "
      + (if .outcome == "bumped" then "bumped" else "**\(.outcome)**: \(.reason)" end) + " |"' "$applied"
    echo ""
  fi
else
  if [ "$(jq '.holds | length' "$verdict")" -gt 0 ]; then
    echo "| Held back | Reason | Evidence |"
    echo "|---|---|---|"
    jq -r '.holds[] | "| `\(.name)` | \(.reason) | \(.evidence) |"' "$verdict"
    echo ""
  fi
fi

# One block per moving container the model wrote notes for, in the
# collector's order. Only the ones that were bumped when the applied list
# is given: a held image's notes are the hold's reason, printed above.
while IFS=$'\t' read -r name from to; do
  if [ -n "$applied" ] && [ -s "$applied" ] \
     && ! jq -e --arg n "$name" 'any(.[]; .name == $n and .outcome == "bumped")' "$applied" >/dev/null; then
    continue
  fi
  note=$(jq -c --arg n "$name" '[.containers[] | select(.name == $n)] | first // empty' "$verdict")
  [ -n "$note" ] || continue
  echo "### \`$name\`: $from → $to"
  echo ""
  for field in watch_for before_deploying highlights; do
    text=$(jq -r --arg f "$field" '.[$f] // "" | gsub("^\\s+|\\s+$"; "")' <<<"$note")
    [ -n "$text" ] || continue
    case "$field" in
      watch_for) echo "**Watch for**" ;;
      before_deploying) echo "**Before deploying**" ;;
      highlights) echo "**Highlights**" ;;
    esac
    echo ""
    echo "$text"
    echo ""
  done
done < <(jq -r '.[] | select(.state == "changed") | [.name, .current, .target] | @tsv' "$containers")
