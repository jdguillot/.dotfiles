You are refreshing the documentation of this repository: `README.md` and
`docs/*.md`. The working tree is a full clone of the repository, freshly
checked out of `main`. A separate file, `docs-report/summary.md`, lists
the commits since the last docs refresh. Read that first, then read
`AGENTS.md` for the repository's own description of what it does and how
it is organised.

Your job is to update the docs to match the current state of the repo.
Concretely:

- **New modules** that have landed since the last refresh should appear
  in `README.md` (overview) and, if they have options worth documenting,
  get a section in `docs/MODULES.md` or `docs/HOME-MANAGER.md`. The
  `cyberfighter.*` option namespace is where they live; the module file
  under `modules/features/` or `home/modules/features/` is the source of
  truth for the option names and defaults.
- **New or removed hosts** should appear in the Current Hosts table in
  `README.md` and in `docs/HOSTS.md`. The table stays a table. New
  columns get a one-sentence description in the table's header row.
- **Option changes** in modules that are already documented (renames,
  defaults, new options) should update the existing section. Do not add a
  new section for the same module.
- **Deployment, deployment-related, or CI changes** that alter how the
  user runs the machine should be reflected in `docs/DEPLOYMENT.md` or
  `docs/CI.md`, not in `README.md`.
- **Secrets-management changes** are reflected in `docs/SOPS.md`.
- A new `docs/RECOMMENDATIONS.md` entry is fine when the repo's own
  `AGENTS.md` gained a new convention; keep the entry as one or two
  sentences on the convention and its *why*, the same shape as the
  existing entries.

Rules:

- Only modify `README.md` and the `.md` files under `docs/`. Do not touch
  any Nix file, workflow, or other source. (If one of those needs a doc
  change, the doc change is the thing; the code change is a different
  pull request.) The commit in the workflow stages exactly those paths, so
  any other edit you make will be thrown away anyway.
- Do not rewrite sections that are still accurate. Update them in place. A
  section that is still accurate gets no diff, or a one-line diff.
- Follow the existing heading structure, table format, and tone. The
  existing docs read like documentation, not marketing; keep it that way.
- Do not invent options, hosts, or modules that are not in the repo's
  current tree. If the repo dropped something, remove it from the docs
  where it appears, not just ignore it.
- Do not add a "What's new" section. The pull request has a diff; the docs
  should describe the current state, not its history.
- Keep each module section bounded: a paragraph or two on what the module
  does, a list of the options it exposes and their defaults, and a link to
  the upstream reference (mynixos.com for NixOS options, the project
  GitHub for anything else). No step-by-step install guide beyond what
  the module's own `cyberfighter.*` options imply.
- When referencing upstream documentation, fetch the current page to
  confirm the option name still exists. If you cannot confirm the option
  name, drop the link rather than guess.
- Write a one-paragraph note to `docs-report/CHANGELOG.md` at the end of
  your work, summarising what you changed and why. That file becomes part
  of the job log but is not part of the pull-request diff.

Verify your work:

1. `bash -n` is not relevant for markdown, but you may run `markdownlint
   README.md docs/*.md` and fix any violations you find.
2. For any option name you changed or added, read the module's `default.nix`
   and confirm it is in fact `cyberfighter.<family>.<option>` or
   `options.<option>.<name>` in the module's `options = ...` attrset. Do
   not rely on memory.

If you are uncertain about an upstream option name, fetch the current
documentation rather than guess. A wrong option name in the docs is worse
than no link, because readers will copy-paste it.
