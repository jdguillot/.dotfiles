#!/usr/bin/env bash
# Pins one nixpkgs package to the revision main's lock has -- the last one
# that built -- by adding a `pin` entry to the workaround register, and
# leaves the rest of nixpkgs on this week's revision.
#
# For the fix agent, beside hold-input.sh. When the bump breaks the build
# because one package in upstream's tree is broken (a stale hash, its tests
# failing under a new toolchain), holding all of nixpkgs for it freezes
# thousands of packages for one. Every host already runs the pinned version
# -- a build that failed never deployed -- so a pin never moves a package
# backwards. package-pins.nix turns every `pin` block into an overlay, and
# check-workarounds.sh retires the entry once the package builds again at
# the locked nixpkgs (or, with --min-version, once nixpkgs ships that
# version).
#
# Usage: pin-package.sh <attr> "<what is broken upstream>" [<issue or PR url>] [--min-version <v>]
#
# <attr> is a top-level nixpkgs attribute (`go-mockery`, never
# `python3Packages.foo`): the overlay replaces top-level attributes only.
set -euo pipefail

REGISTER="${REGISTER:-workarounds.nix}"
BASE="${PIN_BASE:-origin/main}"

attr="" reason="" url="" min=""
while [ $# -gt 0 ]; do
  case "$1" in
    --min-version) min="${2:?--min-version needs a version}"; shift 2 ;;
    *)
      if [ -z "$attr" ]; then attr="$1"
      elif [ -z "$reason" ]; then reason="$1"
      elif [ -z "$url" ]; then url="$1"
      else echo "pin-package.sh: unexpected argument '$1'" >&2; exit 2; fi
      shift ;;
  esac
done
if [ -z "$attr" ] || [ -z "$reason" ]; then
  echo 'usage: pin-package.sh <attr> "<what is broken upstream>" [<url>] [--min-version <v>]' >&2
  exit 2
fi
case "$attr" in
  *.* | */* | *' '*)
    echo "pin-package.sh: '$attr' is not a top-level nixpkgs attribute; the overlay pins those only" >&2
    exit 1 ;;
esac
id="pin-$attr"

if nix eval --json --file "$REGISTER" \
     --apply "r: (r ? \"$id\") || builtins.any (e: (e.pin.attr or null) == \"$attr\") (builtins.attrValues r)" \
     2>/dev/null | grep -qx true; then
  echo "pin-package.sh: $REGISTER already pins '$attr'" >&2
  exit 1
fi

# The revision main's lock has: what every host built and runs today. The
# root's own nixpkgs node, not `.nodes.nixpkgs` -- that name belongs to
# whichever transitive input claimed it first.
lock=$(git show "$BASE:flake.lock")
node=$(jq -r '.nodes[.root].inputs.nixpkgs | if type == "string" then . else .[0] end' <<<"$lock")
rev=$(jq -r --arg n "$node" '.nodes[$n].locked.rev // empty' <<<"$lock")
narHash=$(jq -r --arg n "$node" '.nodes[$n].locked.narHash // empty' <<<"$lock")
if [ -z "$rev" ] || [ -z "$narHash" ]; then
  echo "pin-package.sh: no locked nixpkgs revision in $BASE's flake.lock" >&2
  exit 1
fi

version=$(nix eval --raw "github:NixOS/nixpkgs/$rev#$attr.version" 2>/dev/null) || {
  echo "pin-package.sh: '$attr' has no version in nixpkgs ${rev:0:12}; is it a top-level package?" >&2
  exit 1
}

# Only a package something here installs is worth a pin: a failure in a
# package no target builds is a failure in something else.
rc=0
mapfile -t where < <(.github/scripts/closure-has.sh "$attr") || rc=$?
case "$rc" in
  0) ;;
  1)
    echo "pin-package.sh: no host or home installs '$attr'. The failing derivation belongs to" >&2
    echo "something else: pin the top-level package it is a dependency of, or hold the input." >&2
    exit 1 ;;
  *)
    echo "pin-package.sh: '$attr' does not evaluate as a package on any target of this flake" >&2
    exit 1 ;;
esac
hosts=$(printf '%s\n' "${where[@]}" | sed -E 's/^home:[^@]+@//' | sort -u)

# Nix string escapes: '' and ${ inside an indented string; " \ and ${ in a
# plain one.
ind() { sed -e "s/''/'''/g" -e 's/\${/'"''"'${/g' <<<"$1"; }
dq() { sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\${/\\${/g' <<<"$1"; }
today=$(date -u +%Y-%m-%d)
short=${rev:0:7}
title=$(cut -c1-120 <<<"$attr $version pinned from nixpkgs $short: $reason")

if [ -n "$min" ]; then
  until="nixpkgs ships \`$attr\` $min or later"
  resolved="    resolved = {
      kind = \"package\";
      attr = \"$attr\";
      input = \"nixpkgs\";
      minVersion = \"$min\";
    };"
else
  until="\`$attr\` builds again at the revision nixpkgs is locked to"
  resolved="    resolved = {
      kind = \"builds\";
      attr = \"$attr\";
      input = \"nixpkgs\";
    };"
fi
upstream="    upstream = { };"
[ -z "$url" ] || upstream="    upstream = {
      issue = \"$(dq "$url")\";
    };"

block="  # WORKAROUND($id)
  $id = {
    title = \"$(dq "$title")\";
    added = \"$today\";
    hosts = [
$(printf '      "%s"\n' $hosts)
    ];
    problem = ''
      $(ind "$reason")
    '';
    workaround = ''
      The \`pin\` below takes \`$attr\` from nixpkgs $short, the revision main
      built last, so every host keeps the $version it already runs while the
      rest of nixpkgs moves; package-pins.nix turns it into an overlay.
      Added by pin-package.sh from the weekly bump's fix stage.
    '';
    files = [ ];
$upstream
    pin = {
      attr = \"$attr\";
      rev = \"$rev\";
      narHash = \"$narHash\";
      version = \"$version\";
    };
$resolved
    retire = \"auto\";
    removal = ''
      Retired by the weekly run once
      $until.
      Deleting this entry is the whole removal; nothing else is fenced.
    '';
  };
  # END WORKAROUND($id)
"

if [ "$(tail -n 1 "$REGISTER")" != "}" ]; then
  echo "pin-package.sh: expected $REGISTER to end with a lone '}'" >&2
  exit 1
fi
backup=$(mktemp)
cp "$REGISTER" "$backup"
restore() { cp "$backup" "$REGISTER"; rm -f "$backup"; }
{
  head -n -1 "$REGISTER"
  echo
  printf '%s' "$block"
  echo "}"
} > "$REGISTER.new"
mv "$REGISTER.new" "$REGISTER"

# The entry has to evaluate, and the pin has to take: the first target that
# installs the package must now see the pinned version through the flake.
if ! nix eval --json --file "$REGISTER" --apply "r: r.\"$id\".pin.version" >/dev/null 2>&1; then
  restore
  echo "pin-package.sh: $REGISTER no longer evaluates with the new entry; nothing was changed" >&2
  exit 1
fi
first="${where[0]}"
case "$first" in
  home:*) got=$(nix eval --raw ".#homeConfigurations.\"${first#home:}\".pkgs.$attr.version" 2>/dev/null || true) ;;
  *) got=$(nix eval --raw ".#nixosConfigurations.$first.pkgs.$attr.version" 2>/dev/null || true) ;;
esac
if [ "$got" != "$version" ]; then
  restore
  echo "pin-package.sh: the pin did not take: $first evaluates $attr to '$got', expected $version; nothing was changed" >&2
  exit 1
fi
rm -f "$backup"

echo "::warning::pinned $attr at $version (nixpkgs $short) for: ${where[*]}"
{
  echo "## Pinned one package after the build failed"
  echo ""
  echo "\`$attr\` stays at $version, from nixpkgs \`$short\` (main's revision), on: ${where[*]}."
  echo ""
  echo "$reason"
  echo ""
  echo "The rest of nixpkgs moves. The register entry \`$id\` retires itself once $until."
} >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"
