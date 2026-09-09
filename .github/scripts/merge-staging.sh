#!/usr/bin/env bash
# Merges every remote branch that starts with `staging/` into HEAD. Attempts
# them one at a time, in sorted order, so one bad branch does not block the
# others. A branch that cannot be merged cleanly — a content conflict, or a
# history that cannot merge without a rebase — is skipped and reported; the
# update is not held for it.
#
# Is called from two jobs:
#   - staging: merge in its own working tree and upload the report; the
#              `green` output there is the gate for opening a PR on a
#              no-bump week.
#   - update:  merge again in its own tree, before the bump is applied and
#              the builds run. Same branches and same starting tree as the
#              scan-side run -> same order of attempts -> same outcome.
#
# Does not do anything else: no `git push`, no lock-file changes, no
# bump-commit. Callers that have the push permission are free to use the
# output as a base for further work.
#
# Requires a full clone; `git merge` needs ancestry. Callers must use
# `actions/checkout@v7` with `fetch-depth: 0`, or the default depth.
#
# Writes, under $OUT_DIR (default: staging-report):
#   staging.md     markdown report for the job summary and the pull request
#   result.json    { merged: [...], skipped: [...], untouched: [...] }
#   merged.any     marker file, present iff at least one branch merged. The
#                  caller uses it to decide whether this tree has staged
#                  work, and therefore a reason to push a pull request even
#                  on a no-bump week.
#   staged-commits.txt   the oneline subjects of every commit the merged
#                  branches contributed, newest first. Empty if nothing
#                  merged. This is what the scan LLM reads to judge the
#                  staged work against this week's upstream changes; giving
#                  it the subjects (not the diff) keeps the call bounded and
#                  the model honest about what it can actually verify.
set -euo pipefail

OUT_DIR="${OUT_DIR:-staging-report}"
md="$OUT_DIR/staging.md"
result="$OUT_DIR/result.json"
marker="$OUT_DIR/merged.any"
staged_commits="$OUT_DIR/staged-commits.txt"
mkdir -p "$OUT_DIR"
: > "$staged_commits"

# -t fetches the remote's branch refs (not just HEAD); --prune drops
# tracking refs whose remote branch is gone, so a deleted branch is not
# attempted. Both are no-ops on a full clone that already has the refs.
git fetch -t --prune origin

mapfile -t branches < <(
  git for-each-ref --format='%(refname:short)' 'refs/remotes/origin/staging/*' \
    | sed 's@^origin/@@' | sort
)

merged=()
skipped=()
untouched=()

for b in ${branches[@]+"${branches[@]}"}; do
  full="origin/$b"
  count=$(git rev-list --count "HEAD..$full" 2>/dev/null || echo 0)
  if [ "$count" -eq 0 ]; then
    untouched+=("$b")
    echo "up-to-date: $b (no new commits over HEAD)"
    continue
  fi

  echo "::group::merge staging/$b ($count commits over HEAD)"
  # The merge is the only step that can fail in a way we need to recover
  # from, so it is the only one we isolate with set +e. A failure is not
  # fatal to the loop: we just need to roll back and move on to the next
  # branch.
  set +e
  git merge --no-ff --no-edit -m "Merge staging/$b" "$full" >/dev/null 2>&1
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    merged+=("$b")
    echo "merged: $b ($count commits)"
  else
    skipped+=("$b")
    # Roll back the merge attempt. `git merge --abort` is a no-op (with a
    # warning on stderr, which we suppress) if the merge failed before it
    # actually started. `|| true` keeps us safe in both cases.
    git merge --abort >/dev/null 2>&1 || true
    echo "skipped: $b does not merge cleanly ($count commits)"
    echo "::warning::staging/$b left out of the tree; the report in the pull request body has the full list"
  fi
  echo "::endgroup::"
done

# Collect the commit subjects the merged branches brought in. The
# `origin/main..HEAD` range picks up everything the merges above added;
# subjects only, not the diff, because the scan LLM gets them as bounded
# evidence to reason about without pretending it can verify them.
if [ ${#merged[@]} -gt 0 ]; then
  git log --oneline --no-merges "origin/main..HEAD" >> "$staged_commits"
fi

# Markdown report, for the pull request reader.
{
  echo "## Staged branches"
  echo ""
  if [ ${#branches[@]} -eq 0 ]; then
    echo "No \`staging/*\` branches on the remote. Nothing to pull in."
  else
    if [ ${#merged[@]} -gt 0 ]; then
      echo "### Merged into this pull request"
      echo ""
      for b in "${merged[@]}"; do printf -- '- \`staging/%s\`' "$b"; echo; done
      echo ""
    fi
    if [ ${#skipped[@]} -gt 0 ]; then
      echo "### Left out of this pull request"
      echo ""
      echo "These did not merge cleanly against the tree being updated. They stay on their own branches and will need their own pull request. Their presence here is for awareness; it does not affect whether the update itself ships."
      echo ""
      for b in "${skipped[@]}"; do printf -- '- \`staging/%s\`' "$b"; echo; done
      echo ""
    fi
    if [ ${#untouched[@]} -gt 0 ]; then
      echo "### Already up to date with \`main\`"
      echo ""
      for b in "${untouched[@]}"; do printf -- '- \`staging/%s\`' "$b"; echo; done
      echo ""
    fi
  fi
  echo "_Generated by \`.github/scripts/merge-staging.sh\`; the per-branch attempt log is in the job output._"
} > "$md"

# Sidecar JSON for the LLM and for the pull request body.
#
# `to_json_array` is a helper that turns a file of one element per line
# into a JSON array of strings, or `[]` if the file is empty or absent.
to_json_array() {
  local file="$1"
  if [ -s "$file" ]; then
    sed -e '/^[[:space:]]*$/d' "$file" | jq -R . | jq -s .
  else
    echo "[]"
  fi
}

tmp="$OUT_DIR"
printf '%s\n' ${merged[@]+"${merged[@]}"}                 > "$tmp/.merged"
printf '%s\n' ${skipped[@]+"${skipped[@]}"}               > "$tmp/.skipped"
printf '%s\n' ${untouched[@]+"${untouched[@]}"}           > "$tmp/.untouched"

jq -n \
  --argjson m "$(to_json_array "$tmp/.merged")" \
  --argjson s "$(to_json_array "$tmp/.skipped")" \
  --argjson u "$(to_json_array "$tmp/.untouched")" \
  '{ merged: $m, skipped: $s, untouched: $u }' > "$result"

rm -f "$tmp/.merged" "$tmp/.skipped" "$tmp/.untouched"

# Caller marker: present iff any branch merged.
if [ ${#merged[@]} -gt 0 ]; then
  echo "true" > "$marker"
else
  rm -f "$marker"
fi

echo "staging: ${#merged[@]} merged, ${#skipped[@]} skipped, ${#untouched[@]} already up to date"
jq . "$result"
