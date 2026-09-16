#!/usr/bin/env bash
# Upstream signal for a handful of nixpkgs *packages*, not inputs.
#
# collect-upstream-signal.sh watches the things this repo pins: flake inputs
# and npins pins. A package inside nixpkgs is neither. nixpkgs moves
# thousands of commits a week, well past that script's noise cap, so a
# `foo: 1.2.3 -> 1.2.4` commit is invisible in the digest and the issues on
# the package's own tracker are never read at all -- they belong to a repo
# nothing here treats as a source. That is how opencode 1.18.30, broken on
# every prompt and reported dozens of times, arrived in a green bump.
#
# So: a short hand-picked list (.github/watched-packages.json) of packages
# where a bad release is expensive, each with the upstream repo to ask
# about. For every one, what version the pinned nixpkgs has, what the
# tracked branch would bring in, and -- only when those differ -- the
# releases in between and what people have filed since.
#
# `repo` carries its forge (`github:owner/repo`) rather than assuming one:
# plenty of nixpkgs packages are developed on GitLab, Codeberg or a project's
# own forge, and a bare `owner/repo` quietly asks GitHub about a repository
# that is not there. Only `github:` is implemented; anything else is named
# and skipped, which is a better answer than an empty section that reads as
# "nothing was filed".
#
# Advisory, like the rest of the scan. A package cannot be held: it moves
# when nixpkgs moves. What this can do is tell the triage model, and the
# person reading the report, that this week's nixpkgs carries a version
# people are currently shouting about -- the answer to which may be to hold
# nixpkgs, or to pin that one package (docs/WORKAROUNDS.md).
#
# Appends the long form to $OUT_DIR/digest.md for the model, and writes
# $OUT_DIR/packages.json plus $OUT_DIR/packages.md -- a compact table for
# the job summary and the pull request body, because the digest is an
# artifact nobody downloads and a section nobody reads is not a check.
set -uo pipefail

OUT_DIR="${OUT_DIR:-upstream-signal}"
WATCHED="${WATCHED_PACKAGES:-.github/watched-packages.json}"
ISSUE_SHOW="${PACKAGE_ISSUE_SHOW:-15}"
LOUD_SHOW="${PACKAGE_LOUD_SHOW:-10}"
RELEASE_SHOW="${PACKAGE_RELEASE_SHOW:-30}"
# How far back to read the tracker when the current version matches no
# release tag (a package whose upstream does not cut GitHub releases).
FALLBACK_DAYS="${PACKAGE_FALLBACK_DAYS:-21}"

mkdir -p "$OUT_DIR"
digest="$OUT_DIR/digest.md"
out="$OUT_DIR/packages.json"
table="$OUT_DIR/packages.md"

echo '[]' > "$out"
[ -s "$WATCHED" ] || { echo "package-signal: no $WATCHED, nothing watched" >&2; exit 0; }

# The root's nixpkgs, resolved through .nodes[.root].inputs. Not
# .nodes.nixpkgs: that name belongs to whichever transitive node claimed it
# first, and on this lock it is a months-old revision from some input's own
# flake. Reading it instead silently answers for the wrong nixpkgs.
node=$(jq -r '.nodes[.root].inputs.nixpkgs | if type == "string" then . else .[0] end' flake.lock)
rev=$(jq -r --arg n "$node" '.nodes[$n].locked.rev' flake.lock)
ref=$(jq -r --arg n "$node" '.nodes[$n].original.ref // "nixos-unstable"' flake.lock)

if [ -z "$rev" ] || [ "$rev" = "null" ]; then
  echo "package-signal: no nixpkgs revision in flake.lock" >&2
  exit 0
fi

# Straight from a nixpkgs revision, never through this repo's own
# nixosConfigurations: a package pinned by an overlay (a workaround) would
# otherwise report its pinned version forever and never show the upstream
# moving past the breakage that pinned it.
version_at() {
  nix eval --raw "github:NixOS/nixpkgs/$1#$2.version" 2>/dev/null || true
}

# ...which leaves the opposite question unanswered: what does this flake
# actually install? Read through a host's pkgs, so any overlay in the tree
# is applied. When the two disagree the package is pinned here, and saying
# so is the difference between "upstream shipped a bad version" and "we
# already dealt with it" -- without this the digest reports a version
# nothing on these machines runs, and the model is invited to recommend a
# fix that is already in the tree.
first_host=$(nix eval .#nixosConfigurations --apply builtins.attrNames --json 2>/dev/null \
  | tr -d '[]" ' | tr ',' '\n' | grep . | head -1)
installed_version() {
  [ -n "$first_host" ] || return 0
  nix eval --raw ".#nixosConfigurations.$first_host.pkgs.$1.version" 2>/dev/null || true
}

VER='def ver: ltrimstr("v") | split(".") | map(tonumber? // 0);'

{
  echo "## Watched nixpkgs packages"
  echo ""
  echo "Packages this repo depends on by name rather than by pin. They move"
  echo "when nixpkgs moves, so none of them can be held on its own; a hold"
  echo "here means holding \`nixpkgs\`."
  echo ""
} >> "$digest"

results='[]'
while read -r attr repo why; do
  forge="${repo%%:*}"
  slug="${repo#*:}"
  if [ "$forge" = "$repo" ] || [ -z "$slug" ]; then
    echo "package-signal: $attr has repo '$repo' without a forge prefix, skipping" >&2
    continue
  fi
  if [ "$forge" != "github" ]; then
    {
      echo "### $attr"
      echo ""
      echo "- watched because: $why"
      echo "- upstream repo: \`$repo\`"
      echo "- **not read**: only \`github:\` sources are implemented."
      echo ""
    } >> "$digest"
    results=$(jq --arg a "$attr" --arg s "$repo" \
      '. + [{attr: $a, repo: $s, state: "unsupported-forge"}]' <<<"$results")
    continue
  fi
  echo "::group::$attr ($slug)"

  have=$(version_at "$rev" "$attr")
  want=$(version_at "$ref" "$attr")
  installed=$(installed_version "$attr")

  if [ -z "$have" ] || [ -z "$want" ]; then
    {
      echo "### $attr"
      echo ""
      echo "- watched because: $why"
      echo "- **could not evaluate** \`$attr.version\` on ${rev:0:12} or \`$ref\`."
      echo ""
    } >> "$digest"
    results=$(jq --arg a "$attr" --arg s "$repo" \
      '. + [{attr: $a, repo: $s, state: "unknown"}]' <<<"$results")
    echo "::endgroup::"
    continue
  fi

  {
    echo "### $attr"
    echo ""
    echo "- watched because: $why"
    echo "- upstream repo: \`$repo\`"
    echo "- pinned nixpkgs (${rev:0:12}) has: **$have**"
    echo "- \`$ref\` would bring: **$want**"
    if [ -n "$installed" ] && [ "$installed" != "$have" ]; then
      echo "- **this flake overrides it to $installed** — it is pinned here"
      echo "  (see \`workarounds.nix\`), so what nixpkgs ships does not reach"
      echo "  these machines until that pin is removed."
    fi
    echo ""
  } >> "$digest"

  if [ "$have" = "$want" ]; then
    echo "_No version change this week._" >> "$digest"
    echo "" >> "$digest"
    results=$(jq --arg a "$attr" --arg s "$repo" --arg h "$have" \
      --arg i "$installed" \
      '. + [{attr: $a, repo: $s, state: "unchanged", have: $h, want: $h,
             installed: (if $i == "" then null else $i end)}]' <<<"$results")
    echo "::endgroup::"
    continue
  fi

  releases=$(gh api "repos/$slug/releases?per_page=$RELEASE_SHOW" 2>/dev/null || echo '[]')

  # The window opens at the release this repo is currently on, so the
  # tracker read covers exactly the versions the bump would step through.
  since=$(jq -r --arg h "$have" "$VER"'
    [ .[] | select((.tag_name | ver) == ($h | ver)) ] | first | .published_at // empty' \
    <<<"$releases")
  [ -n "$since" ] || since=$(date -u -d "$FALLBACK_DAYS days ago" +%Y-%m-%dT%H:%M:%SZ)

  incoming=$(jq -r --arg h "$have" --arg w "$want" "$VER"'
    [ .[] | select(.draft | not)
          | select((.tag_name | ver) > ($h | ver))
          | select((.tag_name | ver) <= ($w | ver)) ]
    | sort_by(.published_at)' <<<"$releases")

  if [ "$(jq 'length' <<<"$incoming")" -gt 0 ]; then
    {
      echo "#### releases being stepped through"
      jq -r '.[] | "- " + .tag_name + " (" + (.published_at[0:10]) + ")"
             + (if .prerelease then " [pre-release]" else "" end)' <<<"$incoming"
      echo ""
    } >> "$digest"
  fi

  # Loudest first, and this is the list that earns the script. Sorting by
  # recency answers "did anyone file something", which on a busy tracker is
  # always yes and buries the answer under a day of feature requests. Sorting
  # by comments answers "are many people hitting the same thing", which is
  # what a release being on fire actually looks like. Reactions are shown
  # alongside because a crash report collects them faster than a discussion.
  # Only the search API can sort this way, hence the second endpoint.
  loud=$(gh api -X GET search/issues \
    -f q="repo:$slug created:>=${since%%T*}" \
    -f sort=comments -f order=desc -f per_page="$LOUD_SHOW" 2>/dev/null || echo '{}')
  if [ "$(jq '.items | length // 0' <<<"$loud")" -gt 0 ]; then
    {
      echo "#### most discussed, filed since ${since%%T*}"
      jq -r '.items[] | "- [" + (if .pull_request then "PR" else "issue" end) + " " + .state + "] "
             + .title
             + " (" + (.comments | tostring) + " comments, "
             + (.reactions.total_count | tostring) + " reactions)"
             + " " + .html_url' <<<"$loud"
      echo ""
    } >> "$digest"
  fi

  issues=$(gh api "repos/$slug/issues?state=all&sort=updated&direction=desc&per_page=$ISSUE_SHOW&since=$since" 2>/dev/null || echo '[]')
  if [ "$(jq 'length' <<<"$issues")" -gt 0 ]; then
    {
      echo "#### most recently touched"
      jq -r '.[] | "- [" + (if .pull_request then "PR" else "issue" end) + " " + .state + "] "
             + .title
             + " (" + (.comments | tostring) + " comments)"
             + (if (.labels|length) > 0 then " (" + ([.labels[].name] | join(", ")) + ")" else "" end)
             + " " + .html_url' <<<"$issues"
      echo ""
    } >> "$digest"
  else
    echo "_Nothing filed upstream since $since._" >> "$digest"
    echo "" >> "$digest"
  fi

  results=$(jq --arg a "$attr" --arg s "$repo" --arg h "$have" --arg w "$want" \
    --argjson issues "$(jq 'length' <<<"$issues")" \
    --argjson loud "$(jq '[.items[]? | select(.comments >= 5)] | length' <<<"$loud")" \
    --arg i "$installed" \
    '. + [{attr: $a, repo: $s, state: "changed", have: $h, want: $w,
           issues: $issues, busy_threads: $loud,
           installed: (if $i == "" then null else $i end)}]' \
    <<<"$results")
  echo "::endgroup::"
done < <(jq -r '.[] | [.attr, .repo, .why] | @tsv' "$WATCHED")

printf '%s\n' "$results" > "$out"

# The compact form. `installed` is only worth a column when it differs from
# what nixpkgs ships, which is exactly the pinned case.
{
  echo "### Watched packages"
  echo ""
  echo "| Package | pinned nixpkgs | incoming | installed here |"
  echo "|---|---|---|---|"
  jq -r '.[]
    | "| `\(.attr)` "
    + "| \(.have // "?") "
    + "| " + (if .state == "unchanged" then "_unchanged_"
              elif .state == "changed" then (.want // "?")
              else "_" + .state + "_" end) + " "
    + "| " + (if (.installed // null) == null then "—"
              elif .installed == .have then "—"
              else .installed + " ⚠ pinned" end)
    + " |"' "$out"
  echo ""
  if jq -e 'any(.[]; (.installed // null) != null and .installed != .have)' "$out" >/dev/null; then
    echo "A pinned package does not take what nixpkgs ships until the pin in"
    echo "\`workarounds.nix\` is removed, so its version columns are upstream"
    echo "news, not a change to these machines."
    echo ""
  fi
} > "$table"

echo "Collected $(jq 'length' "$out") watched package(s) into $digest and $table."
