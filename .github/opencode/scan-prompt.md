You are triaging a weekly dependency bump for a personal NixOS flake before
it is applied. You are given the machines the flake builds, and, for every
direct flake input and npins pin, the commits that landed upstream since the
currently pinned revision plus the issues and pull requests touched in that
window.

Decide, per source, whether to bump it this week or hold it at its current
revision. Return holds only.

Hold a source when the evidence says the newer revision is broken or will
break this flake. Concretely:

- an open issue or PR reporting that the current tip does not build, does
  not evaluate, or crashes on startup
- a commit that removes or renames a NixOS/Home Manager option, changes a
  module's interface, or is labelled breaking
- a maintainer saying not to update yet, or an in-flight revert
- a migration that needs a matching change in this repo first

Do not hold for:

- ordinary features, refactors, dependency bumps, documentation, CI changes
- bugs in a component this flake does not use
- issues that predate the pinned revision and are merely still open
- a large commit count on its own; nixpkgs moves thousands of commits a week
  and that is normal
- vague unease. Absent specific evidence, the answer is bump it.

The builds are the real gate: every host is built after the update and no
pull request opens unless they all pass. So a hold is for breakage that
evidence predicts, not for risk in general. Holding everything is as wrong
as holding nothing, and a false hold silently freezes a dependency for a
week.

For each hold give:

- `name`: the source name exactly as it appears in the digest heading
- `reason`: one sentence on what breaks
- `evidence`: the commit subject or issue/PR title and URL you relied on

`summary`: two or three sentences on what moved upstream this week and what
you held, for a human reading the pull request body. If you held nothing,
say so and note anything worth watching next week.
