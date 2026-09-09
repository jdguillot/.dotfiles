#!/usr/bin/env bash
# Pins one flake input or npins pin back to the revision `main` has, and
# replays the rest of the week's bump on top so everything else still moves.
#
# For the fix agent: when a bump breaks the build because upstream's own tree
# is broken (a stale vendorHash, source that no longer compiles), the fix is
# to wait a week, not to carry a patch that goes stale the moment upstream
# fixes it. This is the only supported way to move the lock files from the
# fix step -- a hand-edited flake.lock does not survive the replay.
#
# Usage: hold-input.sh <name> "<reason>" [<upstream issue or PR url>]
#
# The URL is optional and worth giving when there is one: hold-ledger.sh
# watches it week to week, and a hold with nothing tracked is the one that
# gets forgotten at last month's revision.
set -euo pipefail

name="${1:?usage: hold-input.sh <name> <reason> [url]}"
reason="${2:?usage: hold-input.sh <name> <reason> [url]}"
tracking="${3:-}"

OUT_DIR="${OUT_DIR:-upstream-signal}"
verdict="$OUT_DIR/verdict.json"
sources="$OUT_DIR/sources.json"
late="${LATE_HOLDS:-late-holds.json}"

# A name that matches nothing is silently a no-op inside apply-updates.sh --
# the bump would replay in full and the build would fail again for the same
# reason, with the budget spent. Fail loudly here instead.
#
# Collected into a variable rather than piped into `grep -q`: grep exits on
# the first match, jq takes SIGPIPE, and `pipefail` then reports the whole
# pipeline as failed -- so every name that *does* exist would look unknown.
known=$(
  jq -r '.nodes[.root].inputs | keys[]' flake.lock
  jq -r '.[] | select(.kind == "npin") | .name' "$sources"
)
if ! grep -qxF "$name" <<<"$known"; then
  echo "hold-input.sh: '$name' is not a flake input or an npins pin." >&2
  echo "Flake inputs:" >&2
  jq -r '.nodes[.root].inputs | keys | join(" ")' flake.lock >&2
  echo "Pins:" >&2
  jq -r '[.[] | select(.kind == "npin") | .name] | join(" ")' "$sources" >&2
  exit 1
fi

if jq -e --arg n "$name" 'any(.holds[]; .name == $n)' "$verdict" >/dev/null; then
  echo "hold-input.sh: '$name' was already held this run; nothing to do." >&2
  exit 1
fi

evidence="the bump broke the build and the failure is upstream's own"
jq --arg n "$name" --arg r "$reason" --arg e "$evidence" \
  '.holds += [{ name: $n, reason: $r, evidence: $e }]' "$verdict" > "$verdict.new"
mv "$verdict.new" "$verdict"

# Separate from the scan's verdict because the pull request distinguishes
# them: the scan's holds were predicted from upstream evidence, these were
# found by the build failing.
[ -s "$late" ] || echo '[]' > "$late"
jq --arg n "$name" --arg r "$reason" --arg t "$tracking" \
  '. += [{ name: $n, reason: $r, tracking: $t }]' "$late" > "$late.new"
mv "$late.new" "$late"

# Back to the pre-bump lock files, then replay: `nix flake update` takes an
# explicit name list, so the held input keeps main's revision while every
# other input moves. Only these two paths are restored -- any repository edit
# already in the tree is left alone.
git checkout origin/main -- flake.lock npins/sources.json

echo "::group::replaying the bump without $name"
.github/scripts/apply-updates.sh
echo "::endgroup::"

echo "::warning::held $name at main's revision: $reason"
{
  echo "## Held back after the build failed"
  echo ""
  echo "\`$name\` &mdash; $reason"
  echo ""
  echo "The rest of the week's bump was replayed on top."
} >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"
