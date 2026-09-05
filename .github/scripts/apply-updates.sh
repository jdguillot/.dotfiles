#!/usr/bin/env bash
# Applies the week's bump: every direct flake input and every npins pin
# except the ones the scan held back.
#
# Both tools take an explicit name list, so a hold is a real hold -- the
# input keeps its current revision while everything around it moves. Inputs
# that `follows` nixpkgs still move with nixpkgs; holding those back would
# mean holding nixpkgs.
set -euo pipefail

# git's own stall timeout is five minutes per remote, which is five minutes
# of a weekly job spent on a host that is simply not answering. Abort a
# connection that stops making progress instead; a fetch that is merely slow
# still counts as progress and is left alone.
export GIT_HTTP_LOW_SPEED_LIMIT=1000
export GIT_HTTP_LOW_SPEED_TIME=30

OUT_DIR="${OUT_DIR:-upstream-signal}"
verdict="$OUT_DIR/verdict.json"
sources="$OUT_DIR/sources.json"

held=$(jq -r '[.holds[].name] | join(" ")' "$verdict")
echo "held back: ${held:-(nothing)}"

# Direct inputs come from the lock rather than sources.json so a non-GitHub
# input, which the scan cannot gather evidence for, still gets bumped.
mapfile -t flake_inputs < <(
  jq -r --argjson h "$(jq '[.holds[].name]' "$verdict")" \
    '.nodes[.root].inputs | keys[] | select(. as $n | $h | index($n) | not)' flake.lock
)
mapfile -t pins < <(
  jq -r --argjson h "$(jq '[.holds[].name]' "$verdict")" \
    '[.[] | select(.kind == "npin") | .name][] | select(. as $n | $h | index($n) | not)' "$sources"
)

if [ ${#flake_inputs[@]} -gt 0 ]; then
  echo "::group::nix flake update (${#flake_inputs[@]} inputs)"
  nix flake update "${flake_inputs[@]}"
  echo "::endgroup::"
else
  echo "every flake input was held back"
fi

# One at a time, not one `npins update` over the list: the vendored pins are
# a dozen strangers' repositories, and any one of them being unreachable
# would otherwise abandon the whole bump -- with flake.lock already moved
# above, so the tree is left half-updated. A pin that cannot be reached keeps
# its current revision, which is the same outcome as holding it back.
if [ ${#pins[@]} -gt 0 ]; then
  echo "::group::npins update (${#pins[@]} pins)"
  unreachable=()
  for pin in "${pins[@]}"; do
    if ! npins update "$pin"; then
      unreachable+=("$pin")
    fi
  done
  echo "::endgroup::"

  if [ ${#unreachable[@]} -gt 0 ]; then
    {
      echo "## Pins left at their current revision"
      echo ""
      echo "Unreachable while this ran: \`${unreachable[*]}\`"
      echo ""
      echo "Nothing is wrong with the repository -- these keep the revision"
      echo "they already had, and the next run will pick them up."
    } >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"
    echo "::warning::pins left unchanged, unreachable: ${unreachable[*]}"
  fi
else
  echo "every pin was held back"
fi

git --no-pager diff --stat -- flake.lock npins/sources.json
