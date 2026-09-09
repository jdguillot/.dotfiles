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
# References inside a code span are not linked and raise no event, so the
# fix is to wrap rather than to strip: the reference stays readable and
# copy-pasteable, it just stops being a link.
#
# Fenced blocks are left alone -- backticks inside a fence render literally.
# Job summaries and files on a branch are not issue bodies and raise no
# events, so they do not need this.
set -euo pipefail

exec perl -pe '
  # Track fences so nothing inside one gets rewritten.
  if (/^\s*```/) { $fence = !$fence; next }
  next if $fence;

  # A link to a specific issue or PR carries the whole reference; keep it
  # readable as owner/repo#N rather than a URL nobody reads anyway.
  s{https?://github\.com/([\w.-]+)/([\w.-]+)/(?:issues|pull)/(\d+)\b}{`$1/$2#$3`}g;

  # Any other github.com URL: a commit, a compare, a file. These do not
  # raise issue events, but a commit URL does show up on the commit, so
  # wrap them too.
  s{(?<!`)(https?://github\.com/[^\s<>()\[\]`]+)}{`$1`}g;

  # owner/repo#123 written out longhand.
  s{(?<![`\w/.-])([\w.-]+/[\w.-]+\#\d+)(?![`\w])}{`$1`}g;

  # Bare #123, which would reference this repository. The &-guard keeps
  # HTML entities (&#8212;) intact.
  s{(?<![`\w&/.-])(\#\d+)(?![`\w])}{`$1`}g;
'
