#!/usr/bin/env bash
# Builds the evidence the weekly update agent reasons over: for every direct
# flake input and every npins pin, what landed upstream since the currently
# pinned revision, and what people are saying about it.
#
# Deterministic on purpose -- the model gets a bounded, pre-shaped digest
# instead of GitHub API access. A local 27B is a decent judge and a poor
# researcher, and this way a rate limit or a 404 is a script failure with a
# line number rather than a confused agent.
#
# Writes into $OUT_DIR (default: upstream-signal):
#   sources.json  the update targets, as [{name, kind, owner, repo, rev}]
#   digest.md     the human/model-readable evidence
set -euo pipefail

OUT_DIR="${OUT_DIR:-upstream-signal}"
# Above this many new commits a subject list is noise, not signal (nixpkgs
# moves thousands of commits a week). The count still gets reported.
COMMIT_CAP="${COMMIT_CAP:-300}"
COMMIT_SHOW="${COMMIT_SHOW:-40}"
ISSUE_SHOW="${ISSUE_SHOW:-25}"

mkdir -p "$OUT_DIR"
sources="$OUT_DIR/sources.json"
digest="$OUT_DIR/digest.md"

# Direct inputs only. Transitive nodes are pinned by their own flakes and
# move when the direct input moves, so holding one back means nothing.
jq -n --slurpfile lock flake.lock --slurpfile pins npins/sources.json '
  ($lock[0]) as $l
  | ($l.nodes[$l.root].inputs) as $direct
  | [ $direct | to_entries[]
      | .key as $name
      | (if (.value|type) == "string" then .value else .value[0] end) as $node
      | $l.nodes[$node].locked as $loc
      | $l.nodes[$node].original as $orig
      | select($loc.type == "github")
      # The tracked branch/tag lives in `original`, never in `locked`. Half
      # these inputs pin one (nixos-25.11, legacy-v4, stable, v1.1.0), and
      # comparing those against HEAD would diff them against master.
      | { name: $name, kind: "flake", owner: $loc.owner, repo: $loc.repo,
          rev: $loc.rev, ref: ($orig.ref // "HEAD"),
          since: ($loc.lastModified | todate) } ]
  + [ $pins[0].pins | to_entries[]
      | select(.value.repository.type == "GitHub")
      | { name: .key, kind: "npin", owner: .value.repository.owner,
          repo: .value.repository.repo, rev: .value.revision,
          ref: (.value.branch // "HEAD"), since: null } ]
' > "$sources"

echo "# Upstream signal since the currently pinned revisions" > "$digest"
echo "" >> "$digest"

while read -r name kind owner repo rev ref since; do
  slug="$owner/$repo"
  echo "::group::$name ($slug)"

  # npins records no timestamp, so the pinned commit's own date is the
  # window start. A rev that upstream force-pushed away leaves it empty and
  # the issue window falls back to 14 days.
  if [ "$since" = "null" ]; then
    since=$(gh api "repos/$slug/commits/$rev" --jq '.commit.committer.date' 2>/dev/null || true)
    [ -n "$since" ] || since=$(date -u -d '14 days ago' +%Y-%m-%dT%H:%M:%SZ)
  fi

  cmp=$(gh api "repos/$slug/compare/$rev...$ref" 2>/dev/null || echo '{}')
  ahead=$(jq -r '.ahead_by // "?"' <<<"$cmp")

  {
    echo "## $name"
    echo ""
    echo "- repo: \`$slug\` (${kind}), pinned \`${rev:0:12}\` on \`$ref\`, pinned at $since"
    echo "- new commits upstream: $ahead"
    echo ""
  } >> "$digest"

  if [ "$ahead" != "?" ] && [ "$ahead" -gt 0 ] && [ "$ahead" -le "$COMMIT_CAP" ]; then
    echo "### commits" >> "$digest"
    jq -r --argjson n "$COMMIT_SHOW" \
      '[.commits[].commit.message | split("\n")[0]] | reverse | .[0:$n] | .[] | "- " + .' \
      <<<"$cmp" >> "$digest"
    echo "" >> "$digest"
  elif [ "$ahead" != "?" ] && [ "$ahead" -gt "$COMMIT_CAP" ]; then
    echo "_Commit subjects omitted: $ahead commits is past the $COMMIT_CAP noise cap._" >> "$digest"
    echo "" >> "$digest"
  fi

  # /issues returns pull requests too, which is wanted: an open PR titled
  # "fix busted build" is the strongest single signal there is.
  issues=$(gh api "repos/$slug/issues?state=all&sort=updated&direction=desc&per_page=$ISSUE_SHOW&since=$since" 2>/dev/null || echo '[]')
  if [ "$(jq 'length' <<<"$issues")" -gt 0 ]; then
    echo "### issues and PRs touched since then" >> "$digest"
    jq -r '.[] | "- [" + (if .pull_request then "PR" else "issue" end) + " " + .state + "] "
           + .title
           + (if (.labels|length) > 0 then " (" + ([.labels[].name] | join(", ")) + ")" else "" end)
           + " " + .html_url' <<<"$issues" >> "$digest"
    echo "" >> "$digest"
  fi

  echo "::endgroup::"
done < <(jq -r '.[] | [.name, .kind, .owner, .repo, .rev, .ref, (.since // "null")] | @tsv' "$sources")

echo "Collected $(jq 'length' "$sources") sources into $digest ($(wc -c < "$digest") bytes)."
