#!/usr/bin/env bash
# Removes one entry from the workaround register together with the code it
# fenced: every `WORKAROUND(<id>)` .. `END WORKAROUND(<id>)` block in the
# files the entry lists, then the entry's own block in workarounds.nix.
#
# Deterministic on purpose. A fenced block is a plain line range, and
# deleting a line range is something a plain loop gets right every time,
# which is more than can be said for a model editing Nix. What the markers
# cannot express -- a changed value, a fix woven through a module -- is a
# `manual` entry, and this script refuses it.
#
# The result is verified by evaluating every host the entry names (every
# host, if it names none) before it is kept. An edit that does not evaluate
# is put back exactly as it was, so the weekly build never sees it.
#
# Usage: retire-workaround.sh <id>
set -euo pipefail

id="${1:?usage: retire-workaround.sh <id>}"
REGISTER="${REGISTER:-workarounds.nix}"

entry=$(nix eval --json --file "$REGISTER" --apply "r: r.\"$id\" or null" 2>/dev/null || echo null)
if [ "$entry" = "null" ]; then
  echo "retire-workaround.sh: no entry '$id' in $REGISTER" >&2
  exit 1
fi
if [ "$(jq -r '.retire // "manual"' <<<"$entry")" != "auto" ]; then
  echo "retire-workaround.sh: '$id' is not retire = \"auto\"; removal is a person's job" >&2
  exit 1
fi

mapfile -t files < <(jq -r '.files[]?' <<<"$entry")
files+=("$REGISTER")

start="WORKAROUND($id)"
end="END WORKAROUND($id)"

# Both markers, exactly once each, in every file, before anything is
# touched. A block with one end is not a block, and half a removal is worse
# than none. Fixed strings throughout: the id is not a regex.
for f in "${files[@]}"; do
  if [ ! -f "$f" ]; then
    echo "retire-workaround.sh: '$id' lists $f, which does not exist" >&2
    exit 1
  fi
  e=$(grep -cF "$end" "$f" || true)
  # The end marker contains the start marker's text, so subtract it.
  s=$(( $(grep -cF "$start" "$f" || true) - e ))
  if [ "$s" -ne 1 ] || [ "$e" -ne 1 ]; then
    echo "retire-workaround.sh: $f has $s start / $e end marker(s) for '$id'; need exactly one of each" >&2
    exit 1
  fi
done

# Copies, not `git checkout`, for the restore: the markers may be uncommitted
# in a working tree someone is running this in by hand, and a checkout would
# take them away with the block.
backup=$(mktemp -d)
trap 'rm -rf "$backup"' EXIT
for f in "${files[@]}"; do
  mkdir -p "$backup/$(dirname "$f")"
  cp "$f" "$backup/$f"
done

# Plain bash, no awk: the runner's PATH has none. The output is written
# outside the tree, so a failure part-way leaves no stray file for the
# workflow's `git add -A` to pick up.
strip_block() {
  local line skip=0 ended=0 blank=0
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ $line == *"$end"* ]]; then skip=0; ended=1; continue; fi
    [ "$skip" -eq 1 ] && continue
    if [[ $line == *"$start"* ]]; then skip=1; continue; fi
    # A block usually sits between two blank lines; keep one of them.
    if [ "$ended" -eq 1 ] && [ -z "$line" ] && [ "$blank" -eq 1 ]; then ended=0; continue; fi
    printf '%s\n' "$line"
    if [ -z "$line" ]; then blank=1; else blank=0; fi
    ended=0
  done
}

for f in "${files[@]}"; do
  strip_block < "$f" > "$backup/.retire"
  cat "$backup/.retire" > "$f"
done

restore() {
  for f in "${files[@]}"; do
    cp "$backup/$f" "$f"
  done
}

# The register must still be a valid attrset, and every host the entry named
# must still evaluate without it. `drvPath` is the cheapest thing that forces
# the whole module system.
if ! nix eval --json --file "$REGISTER" > /dev/null 2>&1; then
  echo "retire-workaround.sh: $REGISTER no longer evaluates after removing '$id'; restored" >&2
  restore
  exit 1
fi

mapfile -t hosts < <(jq -r '.hosts[]?' <<<"$entry")
if [ ${#hosts[@]} -eq 0 ]; then
  mapfile -t hosts < <(nix eval .#nixosConfigurations --apply builtins.attrNames --json | jq -r '.[]')
fi
for h in "${hosts[@]}"; do
  if ! nix eval --raw ".#nixosConfigurations.$h.config.system.build.toplevel.drvPath" > /dev/null; then
    echo "retire-workaround.sh: $h does not evaluate without '$id'; restored" >&2
    restore
    exit 1
  fi
done

echo "retired '$id': removed its block from ${files[*]}"
