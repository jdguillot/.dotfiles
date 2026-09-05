#!/usr/bin/env bash
# Applies the week's bump: every direct flake input and every npins pin
# except the ones the scan held back.
#
# Both tools take an explicit name list, so a hold is a real hold -- the
# input keeps its current revision while everything around it moves. Inputs
# that `follows` nixpkgs still move with nixpkgs; holding those back would
# mean holding nixpkgs.
set -euo pipefail

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

if [ ${#pins[@]} -gt 0 ]; then
  echo "::group::npins update (${#pins[@]} pins)"
  npins update "${pins[@]}"
  echo "::endgroup::"
else
  echo "every pin was held back"
fi

git --no-pager diff --stat -- flake.lock npins/sources.json
