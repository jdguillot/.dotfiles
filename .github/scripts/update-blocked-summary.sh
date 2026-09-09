#!/usr/bin/env bash
# Says, in the job summary, why the week's bump did not land.
#
# The run itself finishes green: a bump that does not build is a normal
# weekly outcome, not a broken workflow, and failing the run would put a red
# X on a repository that is fine. That makes this summary the only place the
# outcome is stated, so it has to state it plainly rather than leave a build
# log as the last thing on the page.
set -euo pipefail

log=build-failure.log
budget="${BUDGET_MINUTES:-}"
attempted="${AGENT_ATTEMPTED:-}"
stopped="${AGENT_STOPPED:-}"

# check-and-build.sh writes this line for a build failure. A failure in
# `nix flake check` or the deploy checks reaches here without one.
targets=$(sed -n 's/^failed to build: //p' "$log" | tail -1)

# Every failing target repeats the same trace, so dedupe. The first error is
# the useful one; the cap is because a broken eval can emit dozens.
mapfile -t errors < <(grep -hoE '^ *error: .*' "$log" 2>/dev/null | sed 's/^ *//' | sort -u | head -5)

{
  echo "## The update did not land"
  echo ""
  echo "No pull request was opened and \`main\` is untouched."
  echo ""

  if [ -n "$targets" ]; then
    echo "Failed to build:"
    echo ""
    for t in $targets; do echo "- \`$t\`"; done
    echo ""
  else
    echo "The per-host builds passed; \`nix flake check\` or the deploy-rs"
    echo "checks are what failed."
    echo ""
  fi

  if [ ${#errors[@]} -gt 0 ]; then
    echo "What nix reported:"
    echo ""
    echo '```'
    printf '%s\n' "${errors[@]}"
    echo '```'
    echo ""
  fi

  case "$attempted:$stopped" in
    true:true)
      echo "The fix agent ran and was stopped at its ${budget} minute budget"
      echo "without reaching a green tree. Anything it had edited was still"
      echo "in the tree when the re-check ran, so the errors above may be"
      echo "its half-finished work rather than the original breakage &mdash;"
      echo "compare against the first build in this job's log."
      ;;
    true:*)
      echo "The fix agent ran, finished inside its ${budget} minute budget,"
      echo "and the tree still did not build."
      ;;
    *)
      echo "The fix agent did not run."
      ;;
  esac
  echo ""

  if [ -s fix-notes.md ]; then
    echo "### What the agent made of it"
    echo ""
    cat fix-notes.md
    echo ""
  fi

  echo "### What happens next"
  echo ""
  echo "Nothing here needs undoing &mdash; the bump only ever existed in this"
  echo "job's working tree. Next week's run starts from \`main\` again and"
  echo "retries with a fresh bump, which is often all an upstream breakage of"
  echo "this kind needs."
  echo ""
  echo "To retry now without the input that is breaking it, dispatch this"
  echo "workflow again with **hold** set to that input's name."
} >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"

echo "::warning::the week's bump did not build; no pull request was opened"
