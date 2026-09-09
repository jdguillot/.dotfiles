#!/usr/bin/env bash
# Week-to-week memory for held inputs.
#
# A hold is only ever meant to be temporary, and the failure mode is a quiet
# one: a source sits at last month's revision because every week's run held
# it for the same reason and no run could see that the previous one had.
# This keeps a ledger so each run knows how long a hold has been standing,
# what it is waiting on upstream, and whether that has moved at all.
#
# The ledger lives on its own branch as a single JSON file, written with git
# plumbing so nothing is ever checked out: no working tree to disturb
# mid-bump, no git-crypt smudge on a branch that carries none of it, and a
# blocked week can still record its state without pushing the update branch.
#
# The tracked upstream URLs stay in that file and in job summaries, never in
# a commit message or a pull request body -- see sanitize-refs.sh for why.
#
# Usage:
#   hold-ledger.sh read                 print the ledger (or an empty one)
#   hold-ledger.sh record               merge this week's holds, push, report
set -euo pipefail

BRANCH="${LEDGER_BRANCH:-automated/hold-ledger}"
LEDGER_FILE="${LEDGER_FILE:-holds.json}"
# Three weeks of the same hold with nothing moving upstream is the point at
# which waiting has stopped being a strategy.
ESCALATE_WEEKS="${ESCALATE_WEEKS:-3}"
OUT_DIR="${OUT_DIR:-upstream-signal}"
LATE_HOLDS="${LATE_HOLDS:-late-holds.json}"
REPORT="${HOLD_REPORT:-hold-report.md}"

EMPTY='{"updated":null,"holds":{},"released":[]}'
today=$(date -u +%Y-%m-%d)

fetch_ledger() {
  git fetch -q origin "+refs/heads/$BRANCH:refs/remotes/origin/$BRANCH" 2>/dev/null || true
}

read_ledger() {
  fetch_ledger
  git show "origin/$BRANCH:$LEDGER_FILE" 2>/dev/null || echo "$EMPTY"
}

# One issue or PR's current state, as the ledger stores it. Anything that
# does not answer is recorded as unknown rather than dropped: a rate limit
# must not read as "upstream went quiet", which is what triggers escalation.
probe_ref() {
  local url="$1" api state updated comments
  api=$(sed -E 's#https?://github\.com/([^/]+)/([^/]+)/(issues|pull)/([0-9]+).*#repos/\1/\2/issues/\4#' <<<"$url")
  if [ "$api" = "$url" ]; then
    jq -n --arg u "$url" '{ url: $u, state: "unknown" }'
    return
  fi
  local body
  body=$(gh api "$api" 2>/dev/null) || {
    jq -n --arg u "$url" '{ url: $u, state: "unknown" }'
    return
  }
  state=$(jq -r '.state' <<<"$body")
  updated=$(jq -r '.updated_at' <<<"$body")
  comments=$(jq -r '.comments' <<<"$body")
  # A merged PR reads as "closed" otherwise, which understates the news.
  if [ "$(jq -r '.pull_request.merged_at // "null"' <<<"$body")" != "null" ]; then
    state=merged
  fi
  jq -n --arg u "$url" --arg s "$state" --arg t "$updated" --argjson c "$comments" \
    '{ url: $u, state: $s, updated_at: $t, comments: $c }'
}

cmd_read() { read_ledger; }

cmd_record() {
  local prev held name reason origin urls
  prev=$(read_ledger)

  # This week's holds, from both sources. The scan's `evidence` is free text
  # that usually carries the URL it relied on, so the tracked references are
  # pulled out of it rather than asked for separately.
  held=$(
    jq -n \
      --slurpfile v "$OUT_DIR/verdict.json" \
      --slurpfile l "$( [ -s "$LATE_HOLDS" ] && echo "$LATE_HOLDS" || echo /dev/null )" '
      ([ $v[0].holds[]? | { name, reason, origin: "scan",
                            text: ((.evidence // "") + " " + (.reason // "")) } ]
       + [ $l[0][]?     | { name, reason, origin: "fix-agent",
                            text: ((.tracking // "") + " " + (.reason // "")) } ])
      # Merged, not deduped. hold-input.sh writes its hold into the verdict
      # too -- the replay reads holds from there -- so the same name arrives
      # from both sources, and taking either one alone loses the other half:
      # the verdict copy has no tracking URL, the late copy is the one that
      # says a person did not decide this. Text from both, so a URL is found
      # wherever it was written.
      | group_by(.name)
      | map({ name: .[0].name,
              reason: ((map(select(.origin == "fix-agent"))[0] // .[0]).reason),
              origin: (if any(.[]; .origin == "fix-agent") then "fix-agent" else .[0].origin end),
              text: (map(.text) | join(" ")) })' 2>/dev/null || echo '[]'
  )

  local out="$prev"
  while read -r name; do
    [ -n "$name" ] || continue
    reason=$(jq -r --arg n "$name" '.[] | select(.name == $n) | .reason' <<<"$held")
    origin=$(jq -r --arg n "$name" '.[] | select(.name == $n) | .origin' <<<"$held")
    urls=$(jq -r --arg n "$name" '.[] | select(.name == $n) | .text' <<<"$held" |
      grep -oE 'https?://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/(issues|pull)/[0-9]+' |
      sort -u || true)

    local upstream='[]'
    while read -r u; do
      [ -n "$u" ] || continue
      upstream=$(jq --argjson e "$(probe_ref "$u")" '. += [$e]' <<<"$upstream")
    done <<<"$urls"

    # Three outcomes, not two. "moved" resets the stall counter; "still"
    # advances it; "unknown" -- every probe failed, so a rate limit rather
    # than a quiet week -- leaves it alone and keeps last week's snapshot.
    # Silence is what escalates, so it has to be silence we actually saw.
    #
    # A hold with nothing tracked can never move, so its weeks all count as
    # stalled. That is the right bias: an untracked hold is the one most
    # likely to sit there forgotten.
    out=$(jq \
      --arg n "$name" --arg r "$reason" --arg o "$origin" --arg d "$today" \
      --argjson up "$upstream" '
      (.holds[$n] // null) as $old
      | ($old.upstream // []) as $before
      | ($up | map(select(.state != "unknown"))) as $now
      | ($before | map(select(.state != "unknown"))) as $was
      | (if ($up | length) > 0 and ($now | length) == 0 then "unknown"
         elif ($now | length) > 0 and $now != $was then "moved"
         else "still" end) as $movement
      | .holds[$n] = {
          first_seen: ($old.first_seen // $d),
          last_seen: $d,
          weeks: (($old.weeks // 0) + 1),
          origin: ($old.origin // $o),
          reason: $r,
          upstream: (if $movement == "unknown" then $before else $up end),
          stalled_weeks: (if $movement == "moved" then 0
                          elif $movement == "unknown" then ($old.stalled_weeks // 0)
                          else (($old.stalled_weeks // 0) + 1) end)
        }' <<<"$out")
  done < <(jq -r '.[].name' <<<"$held")

  # Anything the ledger carried that is not held this week came back on its
  # own. Keep a short tail of those: it is the evidence that waiting works,
  # and it is what makes an entry that never appears here stand out.
  out=$(jq --argjson h "$held" --arg d "$today" '
    ([$h[].name]) as $now
    | [ .holds | to_entries[] | select(.key as $k | $now | index($k) | not)
        | { name: .key, weeks: .value.weeks, released: $d } ] as $freed
    | .released = (($freed + .released) | .[0:10])
    | .holds = (.holds | with_entries(select(.key as $k | $now | index($k))))
    | .updated = $d' <<<"$out")

  printf '%s\n' "$out" | jq . > "$LEDGER_FILE.new"
  mv "$LEDGER_FILE.new" "$LEDGER_FILE"
  write_report "$out"
  push_ledger
}

# The report goes into the job summary as it is, and into the pull request
# body through sanitize-refs.sh.
write_report() {
  local out="$1" n
  n=$(jq '.holds | length' <<<"$out")
  : > "$REPORT"
  [ "$n" -gt 0 ] || return 0

  {
    echo "### Held inputs"
    echo ""
    echo "| Input | Held for | Since | Waiting on | Upstream |"
    echo "|---|---|---|---|---|"
    # First sentence only, and a pipe in it would end the cell early: the
    # reason is whatever the model wrote, and the full text is in the ledger
    # anyway. This table is about how long, not about why.
    jq -r '
      def cell: gsub("\n"; " ") | gsub("\\|"; "&#124;");
      def brief: (if test("\\. ") then (split(". ")[0] + ".") else . end)
                 | (if length > 110 then .[0:107] + "&hellip;" else . end);
      .holds | to_entries[] | .value as $v |
      "| `\(.key)` | \($v.weeks) week\(if $v.weeks == 1 then "" else "s" end) | \($v.first_seen) | \($v.reason | brief | cell) | " +
      (if ($v.upstream | length) == 0 then "&mdash;"
       else ([$v.upstream[] | "\(.url) (\(.state))"] | join("<br>")) end) + " |"' <<<"$out"
    echo ""
  } >> "$REPORT"

  # The escalation. Deliberately a prompt to the human rather than anything
  # automatic: filing on someone else's tracker is their call, and the thing
  # that is actually missing by week three is the report nobody has written.
  # weeks - 1, not weeks: the first run has nothing to compare against, so a
  # hold that has never moved since it was first watched reads as one week
  # short. `w - 1` makes "held three weeks, quiet since week one" escalate on
  # week three rather than week four.
  jq -r --argjson w "$ESCALATE_WEEKS" '
    .holds | to_entries[]
    | select(.value.weeks >= $w and .value.stalled_weeks >= ($w - 1))
    | .key' <<<"$out" | while read -r name; do
    [ -n "$name" ] || continue
    {
      echo "#### \`$name\` has been held $(jq -r --arg n "$name" '.holds[$n].weeks' <<<"$out") weeks with nothing moving upstream"
      echo ""
      echo "Waiting has stopped working. Nothing this workflow can do will"
      echo "fix it, and nobody upstream appears to know. Worth reporting it"
      echo "yourself &mdash; what a maintainer will ask for:"
      echo ""
      echo "- the input and both revisions: what \`main\` pins now, and the"
      echo "  revision the bump tried to move to"
      echo "- the exact failure, from the \`update-report\` artifact's"
      echo "  \`build-failure.log\` on the run that first held it"
      echo "  ($(jq -r --arg n "$name" '.holds[$n].first_seen' <<<"$out"))"
      echo "- what in this repo triggers it, if anything: a build that only"
      echo "  fails because of an override here is a different report from"
      echo "  one that fails for everybody"
      echo "- the smallest reproducer you can get to &mdash; usually a single"
      echo "  \`nix build\` against the input's own flake, with no part of"
      echo "  this repo in it. If that reproduces, say so; if it does not,"
      echo "  say that too, it is the more useful half of the report"
      echo "- your nixpkgs revision and the system (\`x86_64-linux\`)"
      echo ""
      if [ "$(jq -r --arg n "$name" '.holds[$n].upstream | length' <<<"$out")" -gt 0 ]; then
        echo "Already tracked, and quiet:"
        echo ""
        jq -r --arg n "$name" '.holds[$n].upstream[] | "- \(.url) &mdash; \(.state)"' <<<"$out"
      else
        echo "Nothing upstream is being tracked for this one, so there may be"
        echo "an existing report that this workflow has never seen. Worth"
        echo "searching before opening a new one."
      fi
      echo ""
    } >> "$REPORT"
  done
}

# Plumbing rather than a checkout: builds the commit out of the index-free
# objects and pushes the ref. Nothing touches the working tree, which is
# mid-bump and about to be built.
push_ledger() {
  local blob tree parent commit
  export GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-github-actions[bot]}"
  export GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-41898282+github-actions[bot]@users.noreply.github.com}"
  export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
  export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"

  blob=$(git hash-object -w "$LEDGER_FILE")
  tree=$(printf '100644 blob %s\t%s\n' "$blob" "$LEDGER_FILE" | git mktree)
  parent=$(git rev-parse -q --verify "refs/remotes/origin/$BRANCH" || true)

  if [ -n "$parent" ] && [ "$(git rev-parse "$parent^{tree}")" = "$tree" ]; then
    echo "hold ledger unchanged"
    return 0
  fi

  # The message carries no upstream reference on purpose; the URLs are in
  # the file, where they raise no cross-reference event.
  if [ -n "$parent" ]; then
    commit=$(git commit-tree "$tree" -p "$parent" -m "chore(ledger): held inputs as of $today")
  else
    commit=$(git commit-tree "$tree" -m "chore(ledger): held inputs as of $today")
  fi

  git push -q origin "$commit:refs/heads/$BRANCH"
  echo "hold ledger pushed to $BRANCH ($(jq '.holds | length' "$LEDGER_FILE") held)"
}

case "${1:-}" in
  read) cmd_read ;;
  record) cmd_record ;;
  *) echo "usage: hold-ledger.sh {read|record}" >&2; exit 2 ;;
esac
