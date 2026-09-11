#!/usr/bin/env bash
# Filters store paths (stdin, one per line) down to those safe for the public
# cachix: drops every path holding a git-crypt file's bytes and every path
# whose closure contains one. attic is LAN-only and still gets everything.
#
# The secret files are whatever .gitattributes routes through git-crypt, so a
# newly encrypted file is covered with no edit here. They are found in the
# store by name -- a path literal lands as /nix/store/<hash>-<basename> -- which
# holds whether or not this checkout is unlocked. A false match only keeps an
# unrelated path off cachix.
#
# Must fail closed: every step feeding the decision is a plain pipeline into a
# file, because set -e/pipefail do not see failures inside <(...).
# Runs on the runner's near-empty PATH: bash, coreutils, findutils, git, nix.
#
# Usage: public-paths.sh < candidates.txt > public.txt
set -euo pipefail
export LC_ALL=C

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

git ls-files -z | git check-attr -z --stdin filter > "$tmp/attrs"
declare -A secret_names=()
while IFS= read -r -d '' file && IFS= read -r -d '' _attr && IFS= read -r -d '' value; do
  if [ "$value" = git-crypt ]; then
    secret_names[${file##*/}]=1
  fi
done < "$tmp/attrs"

if [ ${#secret_names[@]} -eq 0 ]; then
  echo "::error::no git-crypt files found via .gitattributes -- run from the repo checkout" >&2
  exit 1
fi

# Reads store paths on stdin, prints those named like a secret file.
# ${p:44} skips "/nix/store/" and the 32-char hash plus its dash.
secret_paths() {
  local p
  while IFS= read -r p; do
    if [ -n "${secret_names[${p:44}]:-}" ]; then
      printf '%s\n' "$p"
    fi
  done
}

sort -u > "$tmp/candidates"
if ! [ -s "$tmp/candidates" ]; then
  exit 0
fi

xargs nix path-info -r < "$tmp/candidates" | sort -u | secret_paths > "$tmp/secrets"

if [ -s "$tmp/secrets" ]; then
  xargs nix-store --query --referrers-closure < "$tmp/secrets" | sort -u |
    comm -23 "$tmp/candidates" - > "$tmp/public"
else
  cp "$tmp/candidates" "$tmp/public"
fi

# cachix pushes each path's whole closure, so check that closure directly
# rather than trusting the referrer walk.
if [ -s "$tmp/public" ]; then
  xargs nix path-info -r < "$tmp/public" | secret_paths > "$tmp/leaked"
  if [ -s "$tmp/leaked" ]; then
    while IFS= read -r p; do
      echo "::error::secret path would reach cachix: $p" >&2
    done < "$tmp/leaked"
    exit 1
  fi
fi

total=$(wc -l < "$tmp/candidates")
kept=$(wc -l < "$tmp/public")
echo "public-paths: $((total - kept)) of $total paths withheld from cachix" >&2
cat "$tmp/public"
