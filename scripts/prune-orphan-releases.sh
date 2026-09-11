#!/usr/bin/env bash
# Deletes the releases and tags whose commit is no longer in main's history --
# the cleanup after rewriting history to remove something that leaked.
#
# CI records one release per push, tagged with the commit's short SHA. A
# force-push rewrites main but moves no tags, so every tag from the rewritten
# commit onward still pins the old history, and its "Source code" links keep
# serving it. Orphans are found by ancestry, not by name: any tag whose
# commit is not reachable from the new origin/main.
#
# Run it AFTER force-pushing the rewritten main. Dry run by default.
#
# `latest` is reported, never deleted: it is the ref deptui-agent watches,
# and the force-push's own CI run moves it onto the new main once it builds.
#
# Usage: scripts/prune-orphan-releases.sh [--apply]
set -euo pipefail
cd "$(dirname "$0")/.."

apply=false
case "${1:-}" in
  --apply) apply=true ;;
  "") ;;
  *)
    echo "usage: $0 [--apply]" >&2
    exit 2
    ;;
esac

# --force: after a rewrite, local tags can disagree with the remote's.
git fetch --quiet --force --tags origin main

orphans=()
while read -r tag; do
  [ "$tag" = latest ] && continue
  sha=$(git rev-parse "refs/tags/$tag^{commit}")
  git merge-base --is-ancestor "$sha" origin/main && continue
  orphans+=("$tag")
  echo "orphaned: $tag  ${sha:0:12}  $(git log -1 --format=%s "$sha")"
done < <(git ls-remote --tags --refs origin | sed 's|.*refs/tags/||')

if [ ${#orphans[@]} -eq 0 ]; then
  echo "no orphaned tags: every tag is in origin/main's history"
elif ! $apply; then
  echo
  echo "dry run: rerun with --apply to delete these ${#orphans[@]} tag(s) and their releases"
else
  for tag in "${orphans[@]}"; do
    if gh release view "$tag" >/dev/null 2>&1; then
      # Reading a public repo's releases works with any account; deleting
      # needs push access, and a lack of it comes back as a bare 404.
      if ! gh release delete "$tag" --yes --cleanup-tag; then
        echo "could not delete release $tag. Is the active gh account allowed to" >&2
        echo "push to this repo? Check \`gh auth status\`, then \`gh auth switch\`." >&2
        echo "Rerunning is safe: tags already deleted no longer show up." >&2
        exit 1
      fi
    else
      git push --quiet origin --delete "refs/tags/$tag"
    fi
    # The local copy too, or a later `git push --tags` would put it back.
    git tag -d "$tag" >/dev/null
    echo "deleted $tag"
  done
fi

latest=$(git rev-parse --verify --quiet 'refs/tags/latest^{commit}' || true)
if [ -n "$latest" ] && ! git merge-base --is-ancestor "$latest" origin/main; then
  echo
  echo "note: \`latest\` still points at ${latest:0:12} from the old history, and"
  echo "      its tag page still serves that tree. The CI run for the force-push"
  echo "      moves it once it builds; if that run fails, fix it rather than"
  echo "      moving the tag by hand -- the agent deploys whatever it points at."
fi

echo
echo "The old commits stay reachable by SHA on GitHub until Support purges"
echo "them. See \"If a secret reaches the public repo\" in docs/SOPS.md."
