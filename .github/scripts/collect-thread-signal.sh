#!/usr/bin/env bash
# The discussion behind a held input, as evidence for recommend-hold.sh.
#
# Deterministic for the reason collect-upstream-signal.sh gives: the model
# judges a bounded document and never touches the API. Every comment keeps
# who wrote it (author_association, review verdicts) and how people reacted,
# because the prompt ranks maintainer statements above reaction counts and
# needs both to do it.
#
# Linked threads are followed one hop and no further: the decisive statement
# is often in a PR or issue the tracked thread only points at. Repositories
# mentioned (links, `github:owner/repo` flake refs) get their maintenance
# status, since "switch to this fork" is a common recommendation.
#
# Usage: collect-thread-signal.sh <issue-or-pr-url>...    markdown on stdout
set -euo pipefail

COMMENT_SHOW="${COMMENT_SHOW:-30}"
HOP_COMMENT_SHOW="${HOP_COMMENT_SHOW:-12}"
LINK_CAP="${LINK_CAP:-4}"
REPO_CAP="${REPO_CAP:-4}"
BODY_CHARS="${BODY_CHARS:-1500}"
TOTAL_CHARS="${TOTAL_CHARS:-60000}"

[ $# -gt 0 ] || { echo "usage: $0 <issue-or-pr-url>..." >&2; exit 2; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# A jq program: the $-names are jq variables, not shell ones.
# shellcheck disable=SC2016
JQ_DEFS='
  def role: if . == "OWNER" or . == "MEMBER" or . == "COLLABORATOR" then "maintainer (\(.))"
            elif . == "CONTRIBUTOR" then "contributor"
            else "no role" end;
  def reacts: [ ("+1", "heart", "hooray", "rocket", "-1", "confused") as $k
                | select((.[$k] // 0) > 0) | "\($k) x\(.[$k])" ] | join(", ")
              | if . == "" then "none" else . end;
  def clip($n): gsub("\r"; "") | if length > $n then .[0:$n] + " [...]" else . end;
  def quote($p): split("\n") | map($p + .) | join("\n");
'

# "owner/repo number" from an issue or PR URL; empty for anything else.
parse() {
  sed -nE 's#^https?://github\.com/([^/]+)/([^/]+)/(issues|pull)/([0-9]+).*#\1/\2 \4#p' <<<"$1"
}

# First occurrence wins, order kept; no awk on the runner.
uniq_ordered() { cat -n | sort -t$'\t' -k2,2 -u | sort -n | cut -f2-; }

# One thread as markdown. Its raw text (body, reviews, comments) goes to
# $work so the caller can mine it for links.
thread() {
  local slug="$1" num="$2" show="$3" heading="$4" issue reviews comments total txt
  txt="$work/${slug//\//_}-$num.txt"
  issue=$(gh api "repos/$slug/issues/$num" 2>/dev/null) || {
    printf '%s %s#%s\n\n_Could not fetch this thread._\n\n' "$heading" "$slug" "$num"
    return 0
  }
  jq -r '.body // ""' <<<"$issue" > "$txt"

  jq -r --arg h "$heading" --argjson n "$BODY_CHARS" "$JQ_DEFS"'
    "\($h) \(.title)", "",
    "- \(if .pull_request then "pull request" else "issue" end) \(.html_url), "
      + (if .pull_request.merged_at then "merged \(.pull_request.merged_at[0:10])"
         elif .state == "closed" then "closed \(.closed_at[0:10])"
              + (if .state_reason then " (\(.state_reason))" else "" end)
         else "open" end),
    "- opened by \(.user.login), \(.author_association | role), \(.created_at[0:10]); reactions: \(.reactions | reacts)",
    "", (.body // "" | clip($n) | quote("> ")), ""' <<<"$issue"

  if jq -e '.pull_request' >/dev/null <<<"$issue"; then
    reviews=$(gh api "repos/$slug/pulls/$num/reviews?per_page=100" 2>/dev/null || echo '[]')
    jq -r '.[].body // ""' <<<"$reviews" >> "$txt"
    # A bare COMMENTED review is just the envelope of inline comments.
    if jq -e 'any(.[]; .state != "COMMENTED" or (.body // "") != "")' >/dev/null <<<"$reviews"; then
      echo "Reviews:"
      jq -r --argjson n "$BODY_CHARS" "$JQ_DEFS"'
        .[] | select(.state != "COMMENTED" or (.body // "") != "")
        | "- \(.user.login), \(.author_association | role): \(.state)"
          + (if (.body // "") != "" then " -- " + (.body | clip($n) | gsub("\n"; " ")) else "" end)' <<<"$reviews"
      echo ""
    fi
  fi

  comments=$(gh api --paginate "repos/$slug/issues/$num/comments?per_page=100" 2>/dev/null | jq -s 'add // []') ||
    comments='[]'
  jq -r '.[].body // ""' <<<"$comments" >> "$txt"
  total=$(jq length <<<"$comments")
  [ "$total" -gt 0 ] || return 0
  if [ "$total" -gt "$show" ]; then
    echo "Comments (newest $show of $total, oldest first):"
  else
    echo "Comments (all $total, oldest first):"
  fi
  echo ""
  jq -r --argjson s "$show" --argjson n "$BODY_CHARS" "$JQ_DEFS"'
    .[-$s:][]
    | "- **\(.user.login)**, \(.author_association | role), \(.created_at[0:10]); reactions: \(.reactions | reacts)",
      (.body // "" | clip($n) | quote("  > ")), ""' <<<"$comments"
}

# Issue/PR references in a thread's text, as "owner/repo number". Bare #N
# means the thread's own repository.
links() {
  local txt="$1" slug="$2"
  [ -f "$txt" ] || return 0
  {
    grep -oE 'https?://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/(issues|pull)/[0-9]+' "$txt" |
      sed -E 's#^https?://github\.com/##; s#/(issues|pull)/# #'
    grep -oE '(^|[^A-Za-z0-9_./-])[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+#[0-9]+' "$txt" |
      sed -E 's#^[^A-Za-z0-9_.-]##; s/#/ /'
    grep -oE '(^|[^A-Za-z0-9_&/#-])#[0-9]+' "$txt" | sed -E "s|^[^#]*#|$slug |"
  } | uniq_ordered || true
}

# Repositories pointed at by a repo-root link or a flake ref.
repos() {
  local txt="$1"
  [ -f "$txt" ] || return 0
  {
    grep -oE 'github:[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+' "$txt" | sed 's#^github:##'
    grep -oE 'https?://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/?([^/A-Za-z0-9_.-]|$)' "$txt" |
      sed -E 's#^https?://github\.com/##; s#[^A-Za-z0-9_.-]+$##'
  } | sed -E 's#\.git$##; s#\.+$##' | uniq_ordered || true
}

out="$work/out.md"
seen="$work/seen"
for url in "$@"; do
  parse "$url" | cut -d' ' -f1-2 | tr ' ' '#' >> "$seen"
done

for url in "$@"; do
  read -r slug num <<<"$(parse "$url")" || true
  if [ -z "${num:-}" ]; then
    printf '## %s\n\n_Not an issue or pull request URL; skipped._\n\n' "$url" >> "$out"
    continue
  fi
  thread "$slug" "$num" "$COMMENT_SHOW" "## Tracked:" >> "$out"
  txt="$work/${slug//\//_}-$num.txt"

  mapfile -t hops < <(links "$txt" "$slug" | grep -vxF -f <(tr '#' ' ' < "$seen") | head -n "$LINK_CAP" || true)
  if [ "${#hops[@]}" -gt 0 ]; then
    printf '### Threads it links to (one hop, not followed further)\n\n' >> "$out"
    for h in "${hops[@]}"; do
      read -r hs hn <<<"$h"
      echo "$hs#$hn" >> "$seen"
      thread "$hs" "$hn" "$HOP_COMMENT_SHOW" "####" >> "$out"
    done
  fi

  mapfile -t mentioned < <(repos "$txt" | grep -vxF "$slug" | head -n "$REPO_CAP" || true)
  if [ "${#mentioned[@]}" -gt 0 ]; then
    printf '### Repositories it mentions\n\n' >> "$out"
    for r in "${mentioned[@]}"; do
      gh api "repos/$r" --jq '"- \(.full_name): "
        + (if .fork then "fork of \(.parent.full_name)" else "not a fork" end)
        + ", \(.stargazers_count) stars, last push \(.pushed_at[0:10])"
        + (if .archived then ", ARCHIVED" else "" end)
        + (if (.description // "") != "" then " -- \(.description)" else "" end)' \
        >> "$out" 2>/dev/null || echo "- $r: could not fetch" >> "$out"
    done
    echo "" >> "$out"
  fi
done

# Cut from the finished file, not the stream: `head` closing a pipe early
# would kill the writer and fail the run under pipefail.
if [ "$(wc -c < "$out")" -gt "$TOTAL_CHARS" ]; then
  head -c "$TOTAL_CHARS" "$out"
  printf '\n\n_[evidence truncated at %s characters]_\n' "$TOTAL_CHARS"
else
  cat "$out"
fi
