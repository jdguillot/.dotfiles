#!/usr/bin/env bash
# Pins every preloaded compose image (a project's `preloadImages`, on any
# host) to a digest and a Nix hash in images.lock.json -- the image
# counterpart of flake.lock. Each tag is re-resolved: an unchanged digest
# keeps its entry with no download, a moved one (a new tag, or a floating
# tag upstream rebuilt) is fetched and hashed. Entries no host preloads are
# dropped. Every image is linux/amd64, like every host.
#
# Usage, from the repo root: nix run .#lock-images
set -euo pipefail

lock=images.lock.json
[ -f flake.nix ] && [ -f "$lock" ] || { echo "lock-images: run from the repo root" >&2; exit 1; }

# nix-prefetch-docker stages the whole image in $TMPDIR and then copies it
# into the store. /run (the runner's HOME) is a RAM-backed tmpfs.
export TMPDIR=/var/tmp

# The ${h} is Nix interpolation, not shell.
# shellcheck disable=SC2016
mapfile -t wanted < <(
  nix eval --json .#nixosConfigurations --apply '
    hosts: builtins.concatLists (map (h:
      builtins.concatLists (map (p: p.preloadImages)
        (builtins.attrValues hosts.${h}.config.cyberfighter.features.compose.projects)))
      (builtins.attrNames hosts))' | jq -r 'unique[]'
)

new='{}'
for ref in ${wanted[@]+"${wanted[@]}"}; do
  name=${ref%:*}
  tag=${ref##*:}
  digest=$(skopeo inspect --override-os linux --override-arch amd64 --format '{{.Digest}}' "docker://$ref")
  entry=$(jq -c --arg r "$ref" '.[$r] // empty' "$lock")
  if [ -n "$entry" ] && [ "$(jq -r .imageDigest <<<"$entry")" = "$digest" ]; then
    echo "lock-images: $ref unchanged ($digest)" >&2
  else
    echo "lock-images: $ref -> $digest, fetching" >&2
    entry=$(nix-prefetch-docker --quiet --json --os linux --arch amd64 \
      --image-name "$name" --image-digest "$digest" \
      --final-image-name "$name" --final-image-tag "$tag" |
      jq -c '{imageName, imageDigest, hash}')
  fi
  new=$(jq -c --arg r "$ref" --argjson e "$entry" '. + {($r): $e}' <<<"$new")
done

jq -S . <<<"$new" > "$lock.tmp"
mv "$lock.tmp" "$lock"
echo "lock-images: ${#wanted[@]} image(s) locked in $lock" >&2
