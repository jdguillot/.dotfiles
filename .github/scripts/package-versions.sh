#!/usr/bin/env bash
# What the bump actually changes on these machines, package by package.
#
# The upstream digest can only summarise 40 of the several thousand commits
# nixpkgs moves in a week, and most of them are for packages nothing here
# installs. This is the other direction: enumerate what this flake puts on
# its machines, evaluate every version before and after the bump, and diff.
# No list to maintain -- the set comes from the configurations themselves --
# and no guessing about relevance, because everything in it is installed.
#
# `environment.systemPackages` per host plus `home.packages` per standalone
# home configuration. That pair is the working definition of "what I use":
# a module's internal dependencies are not in it, and neither is anything
# pulled in only as a runtime closure, which is the right call -- those move
# constantly and nobody runs them by name.
#
# Pure evaluation, no building, in the shape boot-requirement.sh uses.
#
# Usage:
#   package-versions.sh record  <out.json>
#   package-versions.sh compare <before.json> <after.json>   # markdown to stdout
set -euo pipefail

# Rows in the changed table before the rest are collapsed into a count. A
# quiet week is a handful; a nixpkgs-wide toolchain bump is hundreds, and a
# pull request body has a size limit.
ROW_CAP="${PACKAGE_ROW_CAP:-80}"

# pname/version when the derivation has them, and parseDrvName on `name`
# when it does not -- otherwise a package without pname reports as
# "hello-1.0" with no version and reads as a new package every single week.
read -r -d '' VERSIONS_APPLY <<'NIX' || true
ps: builtins.listToAttrs (map (p:
  if builtins.isAttrs p then
    let parsed = builtins.parseDrvName (p.name or "?");
    in { name = p.pname or parsed.name; value = p.version or parsed.version; }
  else { name = builtins.baseNameOf (toString p); value = ""; }
) ps)
NIX

record() {
  local out="$1" t
  echo "{}" > "$out"

  while read -r t; do
    echo "::group::packages for $t" >&2
    if ! nix eval --json ".#nixosConfigurations.$t.config.environment.systemPackages" \
         --apply "$VERSIONS_APPLY" > "$out.one" 2>/dev/null; then
      echo "package-versions: could not evaluate systemPackages for $t" >&2
      echo "::endgroup::" >&2
      continue
    fi
    jq --arg t "$t" --slurpfile one "$out.one" '.[$t] = $one[0]' "$out" > "$out.tmp"
    mv "$out.tmp" "$out"
    echo "::endgroup::" >&2
  done < <(nix eval .#nixosConfigurations --apply builtins.attrNames --json | tr -d '[]" ' | tr ',' '\n' | grep .)

  # The standalone home targets. Most of the day-to-day tooling lives here
  # rather than in systemPackages, and on the hosts where home-manager runs
  # as a NixOS module these packages are in the user profile, not the system
  # one, so the host evaluation above does not see them either way.
  while read -r t; do
    echo "::group::packages for home $t" >&2
    if ! nix eval --json ".#homeConfigurations.\"$t\".config.home.packages" \
         --apply "$VERSIONS_APPLY" > "$out.one" 2>/dev/null; then
      echo "package-versions: could not evaluate home.packages for $t" >&2
      echo "::endgroup::" >&2
      continue
    fi
    jq --arg t "$t" --slurpfile one "$out.one" '.[$t] = $one[0]' "$out" > "$out.tmp"
    mv "$out.tmp" "$out"
    echo "::endgroup::" >&2
  done < <(nix eval .#homeConfigurations --apply builtins.attrNames --json | tr -d '[]" ' | tr ',' '\n' | grep .)

  rm -f "$out.one"
}

compare() {
  local before="$1" after="$2"
  jq -r -s --argjson cap "$ROW_CAP" '
    .[0] as $a | .[1] as $b
    # Only targets both snapshots have. They are the same tree either side
    # of the bump, so a mismatch means an evaluation failed, and reporting
    # every package on that host as added or removed would be noise.
    | ([ $b | keys[] | select(. as $t | $a | has($t)) ] | sort) as $targets
    | ([ $targets[] as $t | ($a[$t] | keys[]), ($b[$t] | keys[]) ] | unique) as $names
    | [ $names[]
        | . as $n
        | [ $targets[] | { t: ., old: ($a[.][$n] // null), new: ($b[.][$n] // null) } ] as $e
        | ([ $e[].old | select(. != null) ] | unique) as $olds
        | ([ $e[].new | select(. != null) ] | unique) as $news
        | { name: $n, olds: $olds, news: $news,
            # Where it actually moved, and where it could have.
            moved: [ $e[] | select(.old != null and .new != null and .old != .new) | .t ],
            present: [ $e[] | select(.new != null) | .t ] }
      ] as $rows
    | ( $rows | map(select((.olds | length) == 0 and (.news | length) > 0)) ) as $added
    | ( $rows | map(select((.news | length) == 0)) ) as $removed
    | ( $rows | map(select((.moved | length) > 0)) | sort_by(.name) ) as $changed
    | ( if ($changed | length) == 0 and ($added | length) == 0 and ($removed | length) == 0
        then "No package this flake installs changed version in this bump.\n"
        else
          ( if ($changed | length) > 0 then
              "| Package | Before | After | Where |\n|---|---|---|---|\n"
              + ( $changed[0:$cap]
                  | map( "| `\(.name)` "
                       + "| \(.olds | join(", ")) "
                       + "| \(.news | join(", ")) "
                       + "| " + (if (.moved | length) == (.present | length)
                                 then "all" else (.moved | map("`" + . + "`") | join(", ")) end)
                       + " |")
                  | join("\n") )
              + "\n"
              + ( if ($changed | length) > $cap
                  then "\n_… and \(($changed | length) - $cap) more version changes._\n"
                  else "" end )
            else "No version changes.\n" end )
          + ( if ($added | length) > 0 then
                "\n**Added:** " + ( $added | map("`" + .name + "`") | join(", ") ) + "\n"
              else "" end )
          + ( if ($removed | length) > 0 then
                "\n**Removed:** " + ( $removed | map("`" + .name + "`") | join(", ") ) + "\n"
              else "" end )
        end )
  ' "$before" "$after"
}

case "${1:-}" in
  record) record "$2" ;;
  compare) compare "$2" "$3" ;;
  *) echo "usage: $0 record <out.json> | compare <before.json> <after.json>" >&2; exit 2 ;;
esac
