#!/usr/bin/env bash
# Pull locked flake-input sources from another host's nix store instead of
# GitHub. For networks where codeload.github.com 429s per-IP (work egress);
# access-tokens don't help there, so fetch nothing — copy from a peer that
# already has the paths (any host that built this flake, e.g. ryzn-server).
#
# Usage: scripts/copy-flake-inputs.sh [input-name] [user@host]
#   no args        copy every locked input missing from the local store
#   input-name     copy just that flake input (e.g. hermes-agent)
#   user@host      source store (default: cyberfighter@<ryzn-server tailnet IP>;
#                  resolved via `tailscale ip` for a stable IP even with MagicDNS off)
set -euo pipefail
cd "$(dirname "$0")/.."

only=${1:-}
target=${2:-cyberfighter@$(tailscale ip -4 ryzn-server)}

# node key may differ from the input name (follows/dedup), so resolve
# through root's input mapping; narHash -> fixed output path, no network.
paths=()
for input in $(nix eval --raw --impure --expr \
  'builtins.concatStringsSep " " (builtins.attrNames (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.root.inputs)'); do
  [[ -n $only && $input != "$only" ]] && continue
  narHash=$(nix eval --raw --impure --expr \
    "let l = builtins.fromJSON (builtins.readFile ./flake.lock); n = l.nodes.root.inputs.\"$input\"; in l.nodes.\${n}.locked.narHash or \"\"")
  [[ -z $narHash ]] && continue
  path=$(nix-store --print-fixed-path --recursive sha256 \
    "$(nix hash convert --hash-algo sha256 --to nix32 "$narHash")" source)
  if ! nix path-info "$path" >/dev/null 2>&1; then
    echo "missing: $input -> $path"
    paths+=("$path")
  fi
done

if ((${#paths[@]} == 0)); then
  echo "all input sources already in the local store"
  exit 0
fi

# fetchTree sources are content-addressed, so signatures are irrelevant.
nix copy --from "ssh-ng://$target" --no-check-sigs "${paths[@]}"
echo "copied ${#paths[@]} path(s) from $target"
