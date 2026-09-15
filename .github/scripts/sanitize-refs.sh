#!/usr/bin/env bash
# Neutralises upstream issue/PR references on stdin so that text can go into
# a pull request body, an issue, or a commit message here without GitHub
# linking this repository back to them.
#
# This is a public repo. A full issue URL or an `owner/repo#123` in an issue,
# PR or commit body makes GitHub post a cross-reference event on the *other*
# project's issue -- "jdguillot/.dotfiles mentioned this issue" -- which is
# not a thing a private dependency-bump note should be doing to someone
# else's tracker. A bare `#123` is a different bug with the same shape: it
# links to *this* repo's PR 123 and cross-references that instead.
#
# Markdown (the default), for issue and PR bodies: references inside a code
# span are not linked and raise no event, so the fix is to wrap rather than
# to strip -- the reference stays readable and copy-pasteable. Fenced blocks
# are left alone, since backticks inside a fence render literally.
#
# --commit, for commit messages (.githooks/commit-msg): a commit message is
# plain text, not markdown, so a code span is not markup there and cannot be
# trusted to suppress the link. References are spelled out in words instead,
# and fences get no exemption.
#
# Job summaries and files on a branch are not issue bodies and raise no
# events, so they do not need this.
#
# jq rather than sed or perl: the runner's PATH carries only what
# `github-runner.extraPackages` puts there, jq is already load-bearing for
# every other script here, and this needs capture groups and lookarounds
# that sed does not have. Oniguruma provides both.
set -euo pipefail

mode=markdown
case "${1:-}" in
  "") ;;
  --commit) mode=commit ;;
  *) echo "usage: sanitize-refs.sh [--commit] < text" >&2; exit 2 ;;
esac

exec jq -R -s -j --arg mode "$mode" '
  def wrap:
    # A link to a specific issue or PR carries the whole reference; keep it
    # readable as owner/repo#N rather than a URL nobody reads anyway.
    gsub("https?://github\\.com/(?<o>[\\w.-]+)/(?<r>[\\w.-]+)/(?<k>issues|pull)/(?<n>[0-9]+)";
         "`\(.o)/\(.r)#\(.n)`")
    # Any other github.com URL: a commit, a compare, a file. These raise no
    # issue event, but a commit URL does show up on the commit, so wrap them
    # too.
    | gsub("(?<!`)(?<u>https?://github\\.com/[^\\s<>()\\[\\]`]+)"; "`\(.u)`")
    # owner/repo#123 written out longhand.
    | gsub("(?<![`\\w/.-])(?<x>[\\w.-]+/[\\w.-]+#[0-9]+)(?![`\\w])"; "`\(.x)`")
    # Bare #123, which would reference this repository. The &-guard keeps
    # HTML entities (&#8212;) intact.
    | gsub("(?<![`\\w&/.-])(?<y>#[0-9]+)(?![`\\w])"; "`\(.y)`");

  # The same three shapes, with the `#` or the URL gone. The URL is the one
  # place the kind is known; longhand and bare refs could be either.
  def spell:
    gsub("https?://github\\.com/(?<o>[\\w.-]+)/(?<r>[\\w.-]+)/(?<k>issues|pull)/(?<n>[0-9]+)[^\\s<>()\\[\\]`]*";
         "\(.o)/\(.r) \(if .k == "pull" then "PR" else "issue" end) \(.n)")
    | gsub("(?<![\\w/.-])(?<o>[\\w.-]+)/(?<r>[\\w.-]+)#(?<n>[0-9]+)(?!\\w)"; "\(.o)/\(.r) issue/PR \(.n)")
    | gsub("(?<![\\w&/.-])#(?<n>[0-9]+)(?!\\w)"; "issue/PR \(.n)");

  split("\n")
  | if $mode == "commit" then map(spell)
    else
      reduce .[] as $line ({ fence: false, out: [] };
        if ($line | test("^[[:space:]]*```")) then
          .fence = (.fence | not) | .out += [$line]
        elif .fence then
          .out += [$line]
        else
          .out += [$line | wrap]
        end)
      | .out
    end
  | join("\n")
'
