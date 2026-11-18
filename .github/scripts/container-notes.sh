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

# One block per moving container, in the collector's order. Only the ones
# that were bumped when the applied list is given: a held image's notes are
# the hold's reason, printed above.
#
# Each block opens with what needs no judgement: the sections upstream
# itself marks as needing the reader, quoted whole from the release notes,
# and what the evidence behind the model's notes could not show. The
# model's three notes follow, labelled as its reading.
while IFS=$'\t' read -r name from to; do
  if [ -n "$applied" ] && [ -s "$applied" ] \
     && ! jq -e --arg n "$name" 'any(.[]; .name == $n and .outcome == "bumped")' "$applied" >/dev/null; then
    continue
  fi
  echo "### \`$name\`: $from → $to"
  echo ""

  rec=$(jq -c --arg n "$name" '[.[] | select(.name == $n)] | first' "$containers")
  if [ "$(jq '.required // [] | length' <<<"$rec")" -gt 0 ]; then
    echo "**Marked by upstream as needing action** — quoted from the release notes, not summarised:"
    echo ""
    # Headings inside a quoted section would outrank this block's own.
    jq -r '.required[] | "_\(.tag) · \(.heading)_\n\n"
      + (.text | split("\n") | map(if startswith("#") then "**" + sub("^#+\\s*"; "") + "**" else . end) | join("\n"))
      + "\n"' <<<"$rec"
  fi
  gaps=$(jq -r '
    (.gaps // {}) as $g
    | [ (if $g.no_source then "the image names no GitHub repository, so no release notes or issues were read" else empty end),
        (if $g.no_releases then "no GitHub release maps to the tags in this window" else empty end),
        (if ($g.empty // [] | length) > 0 then "no release notes at all for " + ($g.empty | join(", ")) else empty end),
        (if ($g.trimmed // [] | length) > 0
         then "the model read only the first part of " + ($g.trimmed | map("\(.tag) (\(.chars) characters)") | join(", "))
         else empty end),
        (if ($g.unshown // [] | length) > 0 then "the model was given no notes for the oldest releases: " + ($g.unshown | join(", ")) else empty end),
        (if ($g.marker_missing // [] | length) > 0
         then "the `notes-start` hint matched nothing in " + ($g.marker_missing | join(", ")) + ", so the preamble it should drop is still there; fix the hint in `" + .file + "`"
         else empty end) ]
    | map("- " + .) | join("\n")' <<<"$rec")
  if [ -n "$gaps" ]; then
    echo "**What the evidence does not cover**"
    echo ""
    echo "$gaps"
    echo ""
  fi

  note=$(jq -c --arg n "$name" '[.containers[] | select(.name == $n)] | first // empty' "$verdict")
  if [ -z "$note" ]; then
    echo "_The model wrote no notes for this image._"
    echo ""
    continue
  fi
  echo "_The notes below are the local model's reading of those release notes and of this repository's files for the image._"
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
