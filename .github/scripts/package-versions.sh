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
# Pure evaluation, no building, in the shape boot-requirement.sh uses, and
# with the same "before": the tree the machines run, ahead of the
# `staging/*` merges, so a package a staged branch adds or pins shows up.
#
# Usage:
#   package-versions.sh record  <out.json>
#   package-versions.sh compare <before.json> <after.json> [<summary.json>]
#       markdown to stdout; counts and names as JSON to <summary.json>
set -euo pipefail

# Rows in the changed table before the rest are collapsed into a count. A
# quiet week is a handful; a nixpkgs-wide toolchain bump is hundreds, and a
# pull request body has a size limit. A row is a group: packages that made
# the same move on the same machines share one (a desktop's forty
# components going 6.8.2 -> 6.8.3 is one fact, not forty).
ROW_CAP="${PACKAGE_ROW_CAP:-80}"
# Names spelled out in a grouped row before the rest become a count, and
# rows in the one-per-package list kept under the fold.
GROUP_NAMES="${PACKAGE_GROUP_NAMES:-6}"
FULL_CAP="${PACKAGE_FULL_CAP:-300}"

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
  local before="$1" after="$2" summary_out="${3:-}" result
  result=$(jq -c -s --argjson cap "$ROW_CAP" --argjson shown "$GROUP_NAMES" --argjson full "$FULL_CAP" '
    .[0] as $a | .[1] as $b
    # Only targets both snapshots have: a target missing from one side
    # failed to evaluate there, and reporting every package on it as added
    # or removed would be noise. They are named below instead.
    | ([ $b | keys[] | select(. as $t | $a | has($t)) ] | sort) as $targets
    | ((($a | keys) + ($b | keys) | unique) - $targets) as $uncompared
    # Hosts, not targets: a home target `user@host` counts for its host.
    | def hostof: sub("^[^@]*@"; "");
      # The leading number, or the first two under 0.x: the part of a
      # version that semver lets carry a breaking change. A date
      # (2026-08-16) keeps its year and is not flagged.
      def lead: [scan("[0-9]+") | tonumber]
        | if length == 0 then null elif .[0] == 0 then .[0:2] else .[0:1] end;
      ($targets | map(hostof) | unique) as $hosts
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
        | .where = ((.moved | map(hostof) | unique) as $m
                    | if $m == $hosts then "all" else ($m | map("`" + . + "`") | join(", ")) end)
        | .major = ((.olds | length) == 1 and (.news | length) == 1
                    and (.olds[0] | lead) != null and (.olds[0] | lead) != (.news[0] | lead))
      ] as $rows
    | ( $rows | map(select((.olds | length) == 0 and (.news | length) > 0)) ) as $added
    | ( $rows | map(select((.news | length) == 0)) ) as $removed
    | ( $rows | map(select((.moved | length) > 0)) | sort_by(.name) ) as $changed
    # Same move, same machines: one row. Leading-number moves first.
    | ( $changed | group_by([.olds, .news, .where])
        | map({ names: map(.name), olds: .[0].olds, news: .[0].news, where: .[0].where, major: .[0].major })
        | sort_by([(.major | not), .names[0]]) ) as $groups
    | def cell($v; $major): ($v | join(", ")) | if $major then "**" + . + "**" else . end;
      def row: "| "
        + ( (.names | length) as $n
            | if $n <= $shown then .names | map("`" + . + "`") | join(", ")
              else (.names[0:($shown - 1)] | map("`" + . + "`") | join(", "))
                   + " and \($n - $shown + 1) more" end )
        + " | \(cell(.olds; .major)) | \(cell(.news; .major)) | \(.where) |";
    { summary: {
        changed: ($changed | length),
        major: ($changed | map(select(.major) | .name)),
        added: ($added | map(.name)), removed: ($removed | map(.name)),
        uncompared: $uncompared },
      md: (
        ( if ($changed | length) == 0 and ($added | length) == 0 and ($removed | length) == 0
          then "No package this flake installs changed version in this bump.\n"
          else
            ( if ($changed | length) > 0 then
                "\($changed | length) package(s) change version"
                + ( if any($groups[]; .major) then
                      "; **bold** marks a move in the leading version number (the minor under 0.x), where a release is allowed to break things"
                    else "" end )
                + ".\n\n"
                + "| Package | Before | After | Where |\n|---|---|---|---|\n"
                + ( $groups[0:$cap] | map(row) | join("\n") )
                + "\n"
                + ( if ($groups | length) > $cap
                    then "\n_… and \(($groups | length) - $cap) more rows._\n"
                    else "" end )
                + ( if any($groups[]; (.names | length) > $shown) then
                      "\n<details><summary>Every changed package, one per row</summary>\n\n"
                      + "| Package | Before | After | Where |\n|---|---|---|---|\n"
                      + ( $changed[0:$full]
                          | map("| `\(.name)` | \(.olds | join(", ")) | \(.news | join(", ")) | \(.where) |")
                          | join("\n") )
                      + ( if ($changed | length) > $full
                          then "\n\n_… and \(($changed | length) - $full) more._" else "" end )
                      + "\n\n</details>\n"
                    else "" end )
              else "No version changes.\n" end )
            + ( if ($added | length) > 0 then
                  "\n**Added:** " + ( $added | map("`" + .name + "`") | join(", ") ) + "\n"
                else "" end )
            + ( if ($removed | length) > 0 then
                  "\n**Removed:** " + ( $removed | map("`" + .name + "`") | join(", ") ) + "\n"
                else "" end )
          end )
        + ( if ($uncompared | length) > 0 then
              "\n_Not compared, because it did not evaluate on one side of the bump: "
              + ( $uncompared | map("`" + . + "`") | join(", ") ) + "._\n"
            else "" end ) ) }
  ' "$before" "$after")
  jq -r '.md' <<<"$result"
  [ -z "$summary_out" ] || jq '.summary' <<<"$result" > "$summary_out"
}

case "${1:-}" in
  record) record "$2" ;;
  compare) compare "$2" "$3" "${4:-}" ;;
  *) echo "usage: $0 record <out.json> | compare <before.json> <after.json> [<summary.json>]" >&2; exit 2 ;;
esac
