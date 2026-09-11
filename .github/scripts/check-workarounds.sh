#!/usr/bin/env bash
# Walks the workaround register (workarounds.nix) and asks upstream, per
# entry, whether the fix it is waiting on has shipped. Resolved entries
# marked `retire = "auto"` are removed from the tree by retire-workaround.sh;
# everything else is reported, so the person reading the run knows what to
# do by hand and keeps being told until the entry is gone.
#
# Deterministic, like collect-upstream-signal.sh: each `resolved` probe is a
# GitHub API call or a `nix eval`, never a judgement. A probe that cannot
# answer is `unknown`, which is reported as such rather than read as "still
# waiting" -- a rate limit must not look like upstream being slow.
#
# Runs after apply-updates.sh and before the build, so a `commit` probe sees
# the revision the bump moved to, and a retirement is covered by the same
# build gate as the bump.
#
# Writes:
#   workarounds.json        [{id, state, detail, retire, ...}] per entry
#   workarounds-report.md   for the job summary and the pull request body
set -euo pipefail

REGISTER="${REGISTER:-workarounds.nix}"
REPORT="${WORKAROUNDS_REPORT:-workarounds-report.md}"
RESULTS="${WORKAROUNDS_JSON:-workarounds.json}"

: > "$REPORT"
echo '[]' > "$RESULTS"

if [ ! -f "$REGISTER" ]; then
  exit 0
fi
register=$(nix eval --json --file "$REGISTER")
if [ "$(jq 'length' <<<"$register")" -eq 0 ]; then
  exit 0
fi

# A version is an array of numbers so jq compares it element-wise.
VER='def ver: ltrimstr("v") | split(".") | map(tonumber? // 0);'

probe_release() {
  local repo="$1" min="$2" pre="$3" body
  body=$(gh api "repos/$repo/releases?per_page=50" 2>/dev/null) || { echo 'unknown	the releases API did not answer'; return; }
  jq -r --arg min "$min" --argjson pre "$pre" "$VER"'
    [ .[] | select(.draft | not) | select($pre or (.prerelease | not))
          | select((.tag_name | ver) >= ($min | ver)) ]
    | sort_by(.published_at) | first
    | if . == null then "waiting\tno " + (if $pre then "" else "stable " end)
                        + "release at or past " + $min + " yet"
      else "resolved\t" + (if .prerelease then "pre-release " else "release " end)
           + .tag_name + " on " + (.published_at[0:10]) + " (" + .html_url + ")" end' <<<"$body"
}

# One issue or pull request. Same shape hold-ledger.sh uses.
probe_ref() {
  local url="$1" want="$2" api body state merged
  api=$(sed -E 's#https?://github\.com/([^/]+)/([^/]+)/(issues|pull)/([0-9]+).*#repos/\1/\2/issues/\4#' <<<"$url")
  [ "$api" != "$url" ] || { echo 'unknown	not a GitHub issue or pull request URL'; return; }
  body=$(gh api "$api" 2>/dev/null) || { echo 'unknown	the issues API did not answer'; return; }
  state=$(jq -r '.state' <<<"$body")
  merged=$(jq -r '.pull_request.merged_at // ""' <<<"$body")
  case "$want" in
    merged)
      if [ -n "$merged" ]; then echo "resolved	merged ${merged:0:10} ($url)"
      elif [ "$state" = "closed" ]; then echo "waiting	closed without merging ($url)"
      else echo "waiting	still open ($url)"; fi ;;
    closed)
      if [ "$state" = "closed" ]; then echo "resolved	closed ($url)"
      else echo "waiting	still open ($url)"; fi ;;
  esac
}

# Is <sha> an ancestor of the revision a flake input is now pinned to? Read
# from the lock after the bump, so this answers for the tree being built.
probe_commit() {
  local input="$1" sha="$2" node loc slug rev cmp status
  node=$(jq -r --arg i "$input" '.nodes[.root].inputs[$i] | if type == "string" then . else .[0] end' flake.lock)
  loc=$(jq -c --arg n "$node" '.nodes[$n].locked // null' flake.lock)
  [ "$loc" != "null" ] || { echo "unknown	no flake input named $input"; return; }
  slug=$(jq -r '"\(.owner)/\(.repo)"' <<<"$loc")
  rev=$(jq -r '.rev' <<<"$loc")
  cmp=$(gh api "repos/$slug/compare/$sha...$rev" 2>/dev/null) || { echo 'unknown	the compare API did not answer'; return; }
  status=$(jq -r '.status // "unknown"' <<<"$cmp")
  case "$status" in
    ahead|identical) echo "resolved	$input at ${rev:0:12} contains ${sha:0:12}" ;;
    behind|diverged) echo "waiting	$input at ${rev:0:12} does not contain ${sha:0:12} yet" ;;
    *) echo "unknown	compare returned '$status'" ;;
  esac
}

# The version of a package as the pinned nixpkgs evaluates it for one host.
probe_package() {
  local host="$1" attr="$2" min="$3" v
  v=$(nix eval --raw ".#nixosConfigurations.$host.pkgs.$attr.version" 2>/dev/null) || { echo "unknown	$attr did not evaluate on $host"; return; }
  if jq -en --arg v "$v" --arg min "$min" "$VER"'($v | ver) >= ($min | ver)' > /dev/null; then
    echo "resolved	$attr is $v on $host"
  else
    echo "waiting	$attr is $v on $host, need $min"
  fi
}

results='[]'
while read -r id; do
  entry=$(jq -c --arg i "$id" '.[$i]' <<<"$register")
  kind=$(jq -r '.resolved.kind // "none"' <<<"$entry")
  hosts=$(jq -r '.hosts // [] | join(" ")' <<<"$entry")
  case "$kind" in
    release) line=$(probe_release "$(jq -r .resolved.repo <<<"$entry")" \
                                  "$(jq -r .resolved.minVersion <<<"$entry")" \
                                  "$(jq -r '.resolved.prerelease // false' <<<"$entry")") ;;
    pr)      line=$(probe_ref "$(jq -r .resolved.url <<<"$entry")" merged) ;;
    issue)   line=$(probe_ref "$(jq -r .resolved.url <<<"$entry")" closed) ;;
    commit)  line=$(probe_commit "$(jq -r .resolved.input <<<"$entry")" "$(jq -r .resolved.sha <<<"$entry")") ;;
    package) line=$(probe_package "${hosts%% *}" "$(jq -r .resolved.attr <<<"$entry")" "$(jq -r .resolved.minVersion <<<"$entry")") ;;
    none)    line='waiting	nothing probed: the entry has no `resolved` block' ;;
    *)       line="unknown	probe kind '$kind' is not one this script knows" ;;
  esac
  state=${line%%	*}
  detail=${line#*	}

  action=""
  if [ "$state" = "resolved" ] && [ "$(jq -r '.retire // "manual"' <<<"$entry")" = "auto" ]; then
    echo "::group::retire $id"
    if out=$(.github/scripts/retire-workaround.sh "$id" 2>&1); then
      action="retired"
      echo "$out"
    else
      action="retire-failed"
      echo "$out"
      echo "::warning::$id is fixed upstream but could not be retired automatically"
    fi
    echo "::endgroup::"
  fi

  results=$(jq --argjson e "$entry" --arg id "$id" --arg s "$state" --arg d "$detail" --arg a "$action" \
    '. += [$e + { id: $id, state: $s, detail: $d, action: $a }]' <<<"$results")
done < <(jq -r 'keys[]' <<<"$register")

printf '%s\n' "$results" | jq . > "$RESULTS"

# The report. Upstream URLs stay real here: the job summary raises no
# events, and the pull request body passes through sanitize-refs.sh.
{
  echo "### Workarounds"
  echo ""
  echo "| Workaround | Since | Hosts | Waiting on | This week |"
  echo "|---|---|---|---|---|"
  jq -r '
    def cell: gsub("\n"; " ") | gsub("\\|"; "&#124;");
    .[] |
    (if .resolved.kind == "release" then
        "a " + (if .resolved.prerelease then "" else "stable " end) + "`" + .resolved.repo + "` release ≥ " + .resolved.minVersion
     elif .resolved.kind == "pr" then "merge of " + .resolved.url
     elif .resolved.kind == "issue" then "close of " + .resolved.url
     elif .resolved.kind == "commit" then "`" + .resolved.input + "` to contain " + (.resolved.sha[0:12])
     elif .resolved.kind == "package" then "`" + .resolved.attr + "` ≥ " + .resolved.minVersion
     else "nothing tracked" end) as $on |
    (if .state == "resolved" and .action == "retired" then "**fixed upstream, retired in this run**"
     elif .state == "resolved" and .action == "retire-failed" then "**fixed upstream; automatic removal failed, see below**"
     elif .state == "resolved" then "**fixed upstream, needs a hand**"
     elif .state == "unknown" then "unknown (" + .detail + ")"
     else .detail end) as $week |
    "| `\(.id)` \(.title | cell) | \(.added) | \(.hosts // [] | join(", ")) | \($on) | \($week | cell) |"' "$RESULTS"
  echo ""

  jq -r '.[] | select(.state == "resolved") |
    "#### `\(.id)` is fixed upstream\n\n" +
    "\(.detail)\n\n" +
    (if .action == "retired" then
       "Its block was removed from " + (if (.files | length) > 0 then ((.files | map("`" + . + "`") | join(", ")) + " and ") else "" end)
       + "`workarounds.nix` in this run; every host it names still evaluated, and the build below is the proof.\n"
     elif .action == "retire-failed" then
       "Removing it automatically failed (the run log says why) and nothing was changed. The removal notes:\n\n" + .removal + "\n"
     else
       "Nothing here is automatic for this entry. What to do:\n\n" + .removal + "\n" end)' "$RESULTS"
} >> "$REPORT"

n=$(jq '[.[] | select(.state == "resolved" and .action != "retired")] | length' "$RESULTS")
if [ "$n" -gt 0 ]; then
  echo "::warning::$n workaround(s) are fixed upstream and waiting on a person: $(jq -r '[.[] | select(.state == "resolved" and .action != "retired") | .id] | join(", ")' "$RESULTS")"
fi
echo "checked $(jq 'length' "$RESULTS") workaround(s): $(jq -r 'map(.state) | group_by(.) | map("\(length) \(.[0])") | join(", ")' "$RESULTS")"
