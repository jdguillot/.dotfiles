#!/usr/bin/env bash
# Which of this flake's targets install a nixpkgs package: every host whose
# system closure, and every standalone home whose activation closure,
# contains the package's derivation. The package's own derivation path from
# that target's `pkgs`, matched against `nix-store -qR` of the target, so a
# dependency counts and a package merely named in a comment does not.
#
# Evaluation only, no building. The closures are cached under $CLOSURE_DIR
# for the rest of the run; the first question costs the evaluation of every
# target, the second is a grep.
#
# Usage: closure-has.sh <attr>
#   prints one target per line (`<host>` or `home:<user>@<host>`)
#   exit 0 when at least one target installs it
#   exit 1 when none does
#   exit 2 when <attr> does not evaluate as a package on any target
set -uo pipefail

attr="${1:?usage: closure-has.sh <attr>}"
CLOSURE_DIR="${CLOSURE_DIR:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/closures}"
mkdir -p "$CLOSURE_DIR"

targets() {
  nix eval --json .#nixosConfigurations --apply builtins.attrNames 2>/dev/null | jq -r '.[] | "host\t" + .'
  nix eval --json .#homeConfigurations --apply builtins.attrNames 2>/dev/null | jq -r '.[] | "home\t" + .'
}

# The build closure of one target, from the instantiated toplevel. The eval
# that prints the .drv path is what writes it to the store, so -qR can walk it.
closure_of() {
  local kind="$1" name="$2" file="$CLOSURE_DIR/$kind-$name.txt" drv=""
  if [ ! -s "$file" ]; then
    case "$kind" in
      host) drv=$(nix eval --raw ".#nixosConfigurations.$name.config.system.build.toplevel.drvPath" 2>/dev/null) ;;
      home) drv=$(nix eval --raw ".#homeConfigurations.\"$name\".activationPackage.drvPath" 2>/dev/null) ;;
    esac
    [ -n "$drv" ] && nix-store -qR "$drv" > "$file.tmp" 2>/dev/null && mv "$file.tmp" "$file"
  fi
  [ -s "$file" ] && printf '%s\n' "$file"
}

found=0
evaluated=0
while IFS=$'\t' read -r kind name; do
  pdrv=""
  case "$kind" in
    host) pdrv=$(nix eval --raw ".#nixosConfigurations.$name.pkgs.$attr.drvPath" 2>/dev/null) ;;
    home) pdrv=$(nix eval --raw ".#homeConfigurations.\"$name\".pkgs.$attr.drvPath" 2>/dev/null) ;;
  esac
  [ -n "$pdrv" ] || continue
  evaluated=1
  file=$(closure_of "$kind" "$name") || continue
  if grep -qxF "$pdrv" "$file"; then
    if [ "$kind" = home ]; then echo "home:$name"; else echo "$name"; fi
    found=1
  fi
done < <(targets)

[ "$evaluated" -eq 1 ] || exit 2
[ "$found" -eq 1 ]
