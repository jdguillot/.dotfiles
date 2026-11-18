#!/usr/bin/env bash
# Assembles the weekly pull request body from the scan's and the update
# job's artifacts. A script and not a workflow step so it can be run
# against a downloaded run:
#
#   gh run download <run> -D run
#   HOSTS='["a","b"]' CACHED=success \
#     .github/scripts/pr-body.sh run/upstream-signal run/update-report
#
# Each section is omitted when it has nothing to say, so a clean week reads
# clean. Upstream URLs pass through; the caller pipes the whole body through
# sanitize-refs.sh.
#
# GitHub refuses a body over 65536 characters, and a refused body is a week
# with no pull request. Past BODY_LIMIT bytes the long lists are dropped,
# and past it again the body is cut with a pointer to the artifacts.
#
# Env: HOSTS (JSON list of the hosts that built), CACHED (the cache job's
#      result), GITHUB_RUN_ID / GITHUB_SERVER_URL / GITHUB_REPOSITORY for the
#      footer link (omitted when unset).
set -euo pipefail

sig="${1:-upstream-signal}"
rep="${2:-update-report}"
HOSTS="${HOSTS:-[]}"
CACHED="${CACHED:-}"
export CACHED

n=$(tr -d '[]" ' <<<"$HOSTS" | tr ',' '\n' | grep -c . || true)

render() {
  echo "Weekly update: the week's upstream bump plus any \`staging/*\` work that merged cleanly."
  echo ""
  echo "\`nix flake check\` passed and all $n hosts built on \`ryzn-server\`."
  if [ "$CACHED" = "success" ]; then
    echo "The closure is already in \`attic:main\` and \`cachix:jdguillot\`, so switching pulls rather than builds."
  fi
  echo ""

  # First, and from recorded facts only: what needs a person before
  # the merge and what this run could not see. Everything below it
  # is the detail those lines point into.
  if ! .github/scripts/needs-attention.sh "$sig" "$rep"; then
    echo "## Before you merge"
    echo ""
    echo "**The list of what needs attention could not be built this week. Read the whole body.**"
  fi
  echo ""

  # Nested, not flat: upload-artifact roots a multi-path artifact at
  # the paths' common ancestor, so `staging-report/` survives into
  # the download.
  if [ -s "$rep/staging-report/staging.md" ]; then
    cat "$rep/staging-report/staging.md"
    echo ""
    if [ -s "$rep/staging-report/staged-commits.txt" ]; then
      echo "### Commits landed"
      echo ""
      echo '```'
      cat "$rep/staging-report/staged-commits.txt"
      echo '```'
      echo ""
    fi
  fi

  echo "## Pre-update triage"
  echo ""
  jq -r .summary "$sig/verdict.json"
  echo ""
  staged_notes=$(jq -r '.staged_notes // ""' "$sig/verdict.json")
  if [ -n "$staged_notes" ] && [ "$staged_notes" != "N/A: no staged work merged." ]; then
    echo "### The staged work"
    echo ""
    echo "$staged_notes"
    echo ""
  fi
  if [ "$(jq '.holds | length' "$sig/verdict.json")" -gt 0 ]; then
    echo "### Held at their current revision"
    echo ""
    echo "| Input | Reason | Evidence |"
    echo "|---|---|---|"
    jq -r '.holds[] | "| `\(.name)` | \(.reason) | \(.evidence) |"' "$sig/verdict.json"
    echo ""
  fi

  # The scan's verdict artifact is the one the scan uploaded, so
  # these do not double up with the table above: a hold the fix
  # agent added exists only in the update job's copy.
  if [ -s "$rep/late-holds.json" ] && [ "$(jq 'length' "$rep/late-holds.json")" -gt 0 ]; then
    echo "### Held back after the build failed"
    echo ""
    echo "The bump broke the build and the breakage was in the input's own tree, not in this repository. These keep the revision \`main\` has; the rest of the bump was replayed on top, and the next run picks up the upstream fix."
    echo ""
    echo "| Input | Why |"
    echo "|---|---|"
    jq -r '.[] | "| `\(.name)` | \(.reason) |"' "$rep/late-holds.json"
    echo ""
  fi

  if [ -s "$rep/hold-report.md" ]; then
    cat "$rep/hold-report.md"
    echo ""
  fi

  if [ -s "$sig/release-notes.md" ]; then
    echo "## What landed upstream"
    echo ""
    echo "_Written by the local model from the upstream commit and pull request titles; the package table further down is the exact record._"
    echo ""
    # The model heads its areas at level 2, which would rank them
    # beside this section instead of under it.
    sed 's/^## /### /' "$sig/release-notes.md"
    echo ""
  fi

  if [ -s "$sig/packages.md" ]; then
    cat "$sig/packages.md"
    echo ""
  fi

  # What moved, what was held, and per bumped image what to watch
  # for, what to do on the host first, and what is new. Nothing
  # builds against an image tag, so this is the review material.
  if [ -s "$sig/containers.md" ]; then
    echo "## Containers"
    echo ""
    cat "$sig/containers.md"
    .github/scripts/container-notes.sh \
      "$sig/containers.json" \
      "$sig/containers-verdict.json" \
      "$rep/containers-applied.json"
    echo ""
  fi

  if [ -s "$rep/reboot-notes.md" ]; then
    echo "## Applying this bump"
    echo ""
    cat "$rep/reboot-notes.md"
    echo ""
  fi

  if [ -s "$rep/package-notes.md" ]; then
    echo "## Package versions"
    echo ""
    echo "What this pull request changes about the programs these machines"
    echo "actually install."
    echo ""
    if [ "$compact" = 1 ]; then
      # The one-per-package list is the first thing to go: the grouped
      # table above it says the same and the artifact keeps the rest.
      sed '/^<details>/,/^<\/details>/d' "$rep/package-notes.md"
    else
      cat "$rep/package-notes.md"
    fi
    echo ""
  fi

  # Carries upstream URLs by design; the sanitizer below wraps
  # them like everything else in this body.
  if [ -s "$rep/workarounds-report.md" ]; then
    # Its own section here, not a subsection of the package table
    # it happens to follow.
    sed 's/^### Workarounds$/## Workarounds/; s/^#### /### /' "$rep/workarounds-report.md"
    echo ""
  fi

  if [ -s "$rep/fix-notes.md" ]; then
    echo "## What the fix agent did"
    echo ""
    cat "$rep/fix-notes.md"
    echo ""
    echo "> Written by the agent that made the change. Read the diff outside the lock files carefully."
    echo ""
  fi

  if [ -n "${GITHUB_RUN_ID:-}" ]; then
    echo "<sub>Opened by \`.github/workflows/weekly-update.yml\`, run [\`$GITHUB_RUN_ID\`]($GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID).</sub>"
  fi
}

BODY_LIMIT="${BODY_LIMIT:-58000}"
compact=0
# Without errexit: a section whose input is missing or malformed leaves a
# gap in the body, where failing here would leave the week without one.
out=$(set +e; render)
if [ "$(printf '%s' "$out" | wc -c)" -gt "$BODY_LIMIT" ]; then
  compact=1
  out=$(set +e; render)
fi
if [ "$(printf '%s' "$out" | wc -c)" -gt "$BODY_LIMIT" ]; then
  out="$(printf '%s' "$out" | head -c "$BODY_LIMIT")

[... cut here to fit GitHub's limit on a pull request body; the rest is in this run's \`update-report\` and \`upstream-signal\` artifacts ...]"
fi
printf '%s\n' "$out"
