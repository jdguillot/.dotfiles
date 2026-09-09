# CI

Everything here runs on the self-hosted runners on `ryzn-server`
(`cyberfighter.features.github-runner`, four ephemeral instances). That
choice is load-bearing rather than a cost saving: the jobs share the host's
`/nix/store` and nix-daemon, so a build is warm, its result is already on the
machine the others substitute from, and the cache push happens from the host
that just built it. `ubuntu-latest` would build a desktop closure from
scratch every time and then copy it somewhere else.

Because the repo is public, keep the runners ephemeral and keep "Require
approval for all outside collaborators" on in the repo's Actions settings.
That gate is the only thing between a fork PR editing a workflow and code
running on the server.

The runner's job PATH is nearly empty by design; anything a workflow calls
has to be listed in `github-runner.extraPackages` on `ryzn-server`. Today
that is `cachix`, `attic-client`, `findutils`, `gh`, `jq`, `npins`,
`opencode`, `curl` and `deptui-agent`.

Adding a tool there does nothing until `ryzn-server` is rebuilt, and the
failure that follows is opaque — `jq: command not found` partway through
some script, with nothing connecting it to a pending `nixos-rebuild`. The
bump workflow's jobs therefore open with
`.github/scripts/preflight.sh <tools…>`, which names what is missing and
what to run:

```bash
deploy .#ryzn-server.system --remote-build
```

## `ci.yml` — build, cache, release, deploy

Triggered by pushes to `main`, by pull requests, and weekly on Sundays.

```
               ┌─> build (matrix, one per host) ─┬─> deploy-checks ─┐
list-hosts ────┤                                 ├─> flake-check ───┼─> release ─> deploy
               └─> home  (matrix, one per home) ─┴─> push ──────────┘
```

- **list-hosts** emits the host and home lists, read straight out of the
  flake. A host added to `hosts/default.nix` joins the build matrix with no
  workflow edit. Evaluation only, deliberately: see **flake-check** below.
- **build** builds each host's `system.build.toplevel`. `fail-fast: false`,
  so one broken host does not cancel the others, and each successful build
  uploads its toplevel store path as a `path-<host>` artifact.
- **home** builds each `homeConfigurations.<user>@<host>.activationPackage`,
  the standalone `home-manager switch` targets. Nothing else in CI touches
  them — the host matrix builds `nixosConfigurations`, and the flake check
  only evaluates them — so this is the one part of the check that was not
  already redundant, and it runs in parallel instead of serially inside the
  gate. Their closures reach the caches too, so `hs` on the other machines
  pulls instead of building. The attribute name carries an `@`, so the
  attrpath needs quoting inside the flake reference.
- **flake-check** runs `nix flake check --no-build --show-trace`, *after* the
  matrix rather than ahead of it. Evaluating a flake output can need a store
  path realised — hermes-agent is uv2nix, import-from-derivation throughout —
  and `--no-build` refuses to realise it, so a check run first fails on a cold
  store with `path '...' is not valid`, naming something unrelated to the
  change. By the time the matrix is done the store holds everything. Same
  reasoning, and the same fix, as `check-and-build.sh`.
- **deploy-checks** builds `checks.x86_64-linux.{deploy-schema,deploy-activate}`
  once the matrix has the toplevels those depend on. It runs only when every
  host built; a missing toplevel would fail the activation check for a reason
  that has nothing to do with the deploy config.
- **push** calls the reusable `push-cache.yml` with whatever artifacts exist.
  Hosts that failed simply have no artifact, so a partial run pushes the
  hosts that worked and names the ones it skipped in the job summary.
- **release** force-moves the `latest` tag to the commit and creates or
  updates the GitHub release of the same name. Pushes to `main` only, and
  only once **flake-check**, **deploy-checks** and **push** all succeeded —
  a plain `needs` already skips the job when any of them failed or was
  skipped. The tag is the ref `deptui-agent` watches (see
  `docs/DEPLOYMENT.md`), which is why it may only ever point at a tree that
  built, checked and reached the caches: a host switching to an uncached
  closure would rebuild it locally. The ref is force-moved rather than
  deleted and recreated because the agent resolves it with `git ls-remote`,
  and a poll landing in the gap would find nothing. A tag push matches no
  `branches` filter, so it does not re-trigger the workflow.
- **deploy** runs `deptui-agent kick --watch fleet` then `--watch self`
  over the agent's control socket — the runners are the agent's host, so
  the TCP listener and its token are not involved. The CLI is on the job
  PATH from `github-runner.extraPackages`, and socket access comes from
  `github-runner.extraGroups` putting the runner units in the agent's
  group. A kick is "check now" and names no ref. Kicks that land mid-run
  are queued, so `fleet` runs first and the self-deploy of `ryzn-server`,
  which restarts the agent, waits for it.

### Why the gate keeps `--no-build`

This was tried the other way and measured, so it is worth writing down.

`nix flake check` type-checks every output, collects the derivations among
them — from `checks`, `packages`, `apps`, `devShells`, `hydraJobs` — and
realises that set at the end. `--no-build` skips exactly that last step.
`nixosConfigurations` are *not* in the set: their `system.build.toplevel` is
forced but never queued, which you can see in the check's own output, where
each collected derivation gets a `derivation evaluated to /nix/store/…drv`
line and the NixOS configurations get none.

That makes it tempting to drop the flag, since this flake's whole build set
is two small deploy-rs derivations. It is a trap. `deploy-activate` depends
on each node's profile path, and realising a derivation realises its inputs,
so building it builds every host toplevel — serially, inside the gate,
before the matrix starts. Measured on these runners: **54s with the flag,
7m22s without**, after which every matrix job was a cache hit because that
one job had already done their work.

So the checks are built in their own job after the matrix, where the
toplevels already exist and they cost what they should.

Nor does any of this bear on the intermittent `error: path '...-source' is
not valid`, which is an *evaluation*-time failure: `nix-gc` deletes a flake
input's source while the fetcher cache
(`~/.cache/nix/fetcher-cache-v*.sqlite`) still records it as present, so the
next eval is handed a dead store path and the one after it re-fetches. It has
been seen on both the laptop and the runner. Re-running is the fix.

Two gates are worth understanding:

- The push job requires `needs.list-hosts.result == 'success'`. A skipped
  `needs` still satisfies `!cancelled()`, so the result has to be asserted
  explicitly rather than left implicit. It gates on the eval rather than on
  **flake-check** because flake-check is skipped whenever a single host fails
  to build, and pushing what *did* build is the whole point of this job.
  Nothing is lost by not gating on evaluation: a tree that does not evaluate
  uploads no `path-*` artifacts, and `push-cache.yml` exits 0 on an empty
  root set rather than falling back to anything.
- The weekly run passes `reset-record: true`, which ignores the pushed-paths
  record and re-offers the whole closure, so anything garbage-collected or
  evicted upstream comes back.

## `push-cache.yml` — reusable cache push

Called by both other workflows. Takes the `path-*` artifacts a build job
uploaded, unions their closures, diffs that against a run-to-run record of
what has already been pushed, and uploads only the difference to
`attic:main` and `cachix:jdguillot` — once, not once per host. Reusable
rather than copied because the diffing is subtle enough that a second copy
would drift.

Callers upload one artifact per successfully built host. The artifact name
only has to match `path-*`; its contents are flattened on download, so a
single bundle artifact containing one file per host works as well as one
artifact per host.

## `weekly-update.yml` — the weekly bump

Tuesdays at 05:00 UTC, or on manual dispatch. Dependabot cannot do this:
`.github/dependabot.yml` only understands `github-actions`, so without this
workflow `flake.lock` and `npins/sources.json` move only by hand. The
workflow also pulls in any `staging/*` branch that merges cleanly, so a
week of staged work that is safe to take lands with the week's bump
instead of waiting for its own pull request.

```
scan ──> update ──> cache ──> pr
```

### scan — look before updating

`.github/scripts/merge-staging.sh` walks every `origin/staging/*` branch,
sorted, and attempts a `--no-ff` merge into HEAD. A branch that cannot
merge is skipped and named in the report; the update is not held. The
`updated` job runs the same script against the same starting tree and the
same branches, so it reproduces the same merge result before applying the
bump and building.

`.github/scripts/collect-upstream-signal.sh` walks every direct flake input
and every npins pin and asks GitHub, per source, what landed since the
currently pinned revision and which issues and pull requests were touched in
that window. Direct inputs only: transitive nodes are pinned by their own
flakes and move when the direct input moves, so holding one back means
nothing. The tracked branch or tag comes from the lock's `original` field,
never `locked` — half these inputs pin one (`nixos-25.11`, `legacy-v4`,
`stable`, `v1.1.0`), and comparing those against `HEAD` would diff them
against master.

`.github/scripts/scan-verdict.sh` hands the digest and the list of staged
commits to the local model on this host's loopback Ollama and gets back a
list of inputs to hold at their current revision, plus a short paragraph
on how the staged work interacts with the week's upstream changes — for
example, whether an upstream change in the digest is likely to break
something in the staged diff, or whether the staged work is likely to need
`deploy .#<host> --boot` rather than a plain `switch` on the affected
hosts. It is a plain `curl`, not an agent: the job is one judgement over
one bounded document, and Ollama's JSON-schema constrained decoding makes
the answer parseable by construction. The prompt is
`.github/opencode/scan-prompt.md`.

`.github/scripts/scan-release-notes.sh` makes a second Ollama call with a
different prompt (`.github/opencode/release-notes-prompt.md`) and a
bounded digest of the week's upstream changes, and gets back a short
markdown overview of what landed, grouped by this repo's own module
families. Two calls rather than extending the verdict: the verdict is
constrained-decoded to a schema whose `holds.name` is an enum over the
update-target source names, and the release notes have no such shape.
Keeping them independent means a degraded model degrades one side and not
the other; the failure mode is the same either way (notes advisory, holds
advice, build gate real).

The verdict and the notes both **fail open**. A hold list is advice; the
flake check and the per-host builds are the actual gate, so an unreachable
model or a garbled answer must not stall the week's bump. They record
`degraded: true` or skip the file and proceed without.

### update — apply, prove, and adapt

First the job re-runs `.github/scripts/merge-staging.sh` against the same
starting tree and the same branch list the scan job used, so it reproduces
the same `staging/*` merge result before doing anything else (the scan
job's working tree died with it). Then
`.github/scripts/apply-updates.sh` runs `nix flake update` and `npins update`
with an explicit name list, so a hold is a real hold — that input keeps its
revision while everything around it moves. Inputs that `follows` nixpkgs
still move with nixpkgs; holding those back would mean holding nixpkgs.

The job then works out whether the tree it is about to push is different
from `main` at all — diffing the working tree (staged merges committed,
bump uncommitted) against `origin/main`. A week where nothing staged and
nothing to bump is a legitimate "open no pull request" outcome, and the
rest of the job — the builds, the cache push, the PR — all key off that
`changed` output, so a no-change week ends as a green run with nothing to
read.

`.github/scripts/check-and-build.sh` then builds every host and every
standalone home configuration, and runs `nix flake check --no-build`
afterwards (see below). The builds are sequential rather than a matrix: the
fix step below needs the failing tree and the failing log in one workspace,
and a matrix job cannot hand its working tree to the next job. It builds
every host even after one fails, so a single run surfaces every breakage the
bump caused.

If that fails, `opencode run --auto` gets the failure log and
`.github/opencode/fix-prompt.md`. The prompt gives it two legitimate
outcomes and asks it to decide which one it is looking at *before* editing
anything:

- **adapt the repository**, when the error names a file here and the cause
  is that we call something upstream renamed or removed. This is the common
  case and the diff is a few lines.
- **hold one input back**, via `.github/scripts/hold-input.sh <name>
  "<reason>"`, when the error is in upstream's own tree — a stale
  `vendorHash`, source that no longer compiles, an output that no longer
  evaluates on its own terms. The script pins that one input to the revision
  `main` has and replays the rest of the bump on top, so everything else
  still moves, and records the hold for the pull request body.

The dividing question the prompt gives is whether the fix would edit a
description of *upstream's* package or *this repository's* configuration.
Writing a `vendorHash`, hanging an `.overrideAttrs` off someone else's
derivation, or carrying a patch for another project's source is the wrong
side of that line: upstream fixes it within days, and the workaround then
goes stale silently as a mismatch in the other direction. `hold-input.sh` is
the only supported way to move the lock files from this step; a hand edit
does not survive the replay.

The attempt is bounded: `fix-timeout-minutes` (default 60, changeable on a
manual dispatch) is both a `timeout` around the run and a line in the prompt,
so the agent can wind down and write its notes rather than only being killed.
An hour rather than half of one because the model is on this host's loopback
and shares the GPU with whatever else is running. The failure mode being
guarded against is not a wrong edit -- a wrong edit fails the re-check and no
pull request opens -- but *no* edit: an agent chasing a bad hypothesis holds
the concurrency group and the GPU indefinitely. On a timeout the step appends
a note saying so, along with the diff it was killed holding, because that
unverified edit is what the re-check then builds — an abandoned experiment
produces an error that looks nothing like the one the bump caused.

It gets three skills, built as `.#ci-agent-skills` and linked into its
opencode config: `nixos-managing` and `nix-flakes` for the repo's own subject
matter, and `diagnosing-bugs` for the discipline a small local model most
lacks -- form a hypothesis, test it, and never conclude from a command whose
stderr was discarded. They share the description clamp in
`lib/clamp-skill-description.nix` with the home catalog.

It gets one MCP server, `nixos` (`mcp-nixos`, on the runner's PATH from the
host's `github-runner.extraPackages`). A bump almost always breaks on an
option or attribute that upstream renamed, and that is a question about what
nixpkgs looks like *now* — the model behind the agent was trained months ago
and would otherwise guess. `--pure` on the run only disables external
plugins; MCP servers are a separate part of the config and still load.

The agent's whole session goes to the job log, which is public along with the
repo. That is deliberate rather than accidental: see "What the agent can
reach" below.

The bump is treated as green only if the flake checked and **every** host
built, before or after that fix. Nothing downstream runs otherwise: no
branch is pushed, no cache push, no pull request, and `main` is untouched.

The *run* still finishes green, though — a bump that does not build is a
normal weekly outcome and a red X would be about upstream, not about this
repository. So `.github/scripts/update-blocked-summary.sh` writes the
outcome into the job summary instead: which targets failed, what nix
reported, whether the fix agent ran, was stopped at its budget, or was never
reached, its `fix-notes.md`, and what happens next. It also raises a warning
annotation, which is what shows on the run itself.

To retry a week that an upstream breakage blocked, dispatch the workflow
again with the **hold** input set to the offending source's name — that is
merged into the triage verdict before `apply-updates.sh` runs, so it wins
over whatever the model decided.

#### What the agent can reach

The runner is a systemd `DynamicUser` with `ProtectHome`, `ProtectSystem=strict`
and `NoNewPrivileges`, ephemeral, and **not** in `nix.settings.trusted-users`.
So although ryzn-server can decrypt `secrets/secrets.yaml`, the agent cannot:

- every sops secret lands as `0400 root:root` under `/run/secrets`, and
  `/run/secrets.d` is `drwxr-x--x root:keys` — traversable, not readable;
- both age key sources (`/var/lib/sops-nix/key.txt` and the host ed25519 key)
  are `0600 root`, so it cannot decrypt the checked-in ciphertext either;
- `ProtectHome` hides `/home` and `/root`, so no user's tokens are in reach.

What it *can* read is `/nix/store` and the checkout, both already public. The
one credential in its environment is the workflow's `github.token`, carried in
`NIX_CONFIG` for flake fetches; Actions masks it in logs, and it is scoped to
this repo's `contents`/`pull-requests`.

The one group it is in beyond its own is `deptui-agent`'s
(`github-runner.extraGroups`), for the kick in `ci.yml`. That socket is
the agent's full control surface — pause, cancel, approve as well as kick —
but none of it names a ref: the worst a job can do is deploy, or hold back,
whatever `latest` already points at, and moving `latest` needs the same
`contents: write` a job already has.

That is the whole reason the transcript can go to a public log: there is
nothing in the agent's reach that is not already published. If that stops
being true — a secret widened to a group the runner is in, a job that hands
it a real credential — the transcript has to stop being printed before the
secret is added, not after.

### How the bump has to be applied

`apply-updates.sh` updates pins one at a time rather than handing `npins` the
whole list. The vendored pins are a dozen strangers' repositories, and any one
of them being unreachable would otherwise abandon the bump *after* flake.lock
had already moved, leaving the tree half-updated. An unreachable pin keeps its
current revision -- the same outcome as being held back -- and is named in the
job summary. `GIT_HTTP_LOW_SPEED_*` is set so a stalled remote gives up in
about thirty seconds instead of git's five-minute default; a slow but
progressing fetch is left alone.

`nix flake check` runs **last**, after every host and home has been built,
not first. Evaluating a flake output can need a store path realised --
hermes-agent is uv2nix, which is import-from-derivation throughout -- and
`--no-build` refuses to realise it. The check then fails with `path '...' is
not valid` naming something that has nothing to do with the bump, and passes
on a re-run once the builds have populated the store. That cost one run an
hour of a fix agent chasing a phantom. The cheap `nix eval` of the host and
home lists stays up front as the fail-fast gate, and a genuinely broken
evaluation still fails the per-host build, with a better message.

It runs with `--show-trace`; the per-host `nix build` calls do
not. A failing build already names the offending file and line, and the trace
only adds nixpkgs-internal frames that crowd the log's trim window. The check
is the opposite case: it truncates its own trace by default and tells you to
pass the flag, and its errors reach you through a module chain that the
untraced output never names.

`.github/scripts/boot-requirement.sh` records `kernel`, `initrd` and the
modules tree for every host before the bump and again after it, and names the
hosts a plain `switch` cannot fully apply. It is pure evaluation — no
building — and the result goes in the pull request body.

This is a deterministic check on purpose, not something the triage model is
asked to judge: it is the same comparison `nixos-rebuild` makes to decide
whether a reboot is pending, only across the bump rather than against the
running system.

The modules tree is the entry that earns its place. It is built from
`boot.extraModulePackages` as well as the kernel, so an out-of-tree driver
bump — nvidia, here — shows up even when the kernel is unchanged. That case
is worse than under-applying: new NVML userspace cannot initialise against
the still-loaded old module, so
`nvidia-container-toolkit-cdi-generator` fails activation and takes docker,
traefik, litellm, comfyui and odysseus with it. deploy-rs then rolls the
whole thing back. Use `deploy .#<host> --boot` and reboot for those hosts.

WSL hosts are skipped: they boot the Windows kernel, `boot.kernel.enable` is
false, and `system.build.kernel` / `initialRamdisk` are never defined there —
evaluating them is a hard error, not an empty result. They are recorded as
unchanging and always listed as switch-only.

### cache and pr

The cache push is the same reusable workflow `ci.yml` uses, so the
closure is already in `attic` and `cachix` before anyone reads the PR — a
switch on the other machines pulls rather than builds. The PR job waits for
it but does not require it; a cache hiccup should not cost the week its pull
request, and the body says so if the push did not succeed.
The branch is pushed from the **update** job, not the PR job, because the
agent's fix lives in that working tree and only that job has it. A branch
push is not a pull request, and it only happens once the tree is green
*and* different from `main`.

The PR body, when one opens, is assembled from: the staged-branch report
and the list of commits that landed; the triage summary and its `staged_notes`
paragraph; the held-back table, if anything was held; a second table for
anything the fix agent held *after* the build failed; the release-notes
overview of what landed upstream, grouped by this repo's own module
families; the "how to apply" section from `boot-requirement.sh`; and the
fix agent's note, if the bump needed an in-repo change. Each section is
omitted when it has nothing to say, so a clean week reads clean.

The PR is opened with `PERSONAL_ACCESS_TOKEN` where it exists. A pull
request
opened with the default `GITHUB_TOKEN` does not trigger other workflows —
GitHub suppresses that to avoid recursive runs — so `ci.yml` would never
post a status on it. The builds in the update job already proved the tree;
the PAT is so the PR visibly shows it.

Manual dispatch takes three inputs: `skip-scan` bumps everything without the
triage pass, `fix-timeout-minutes` changes the fix agent's budget, and `hold`
takes a space-separated list of sources to hold regardless of what the triage
says.

## `docs-refresh.yml` — the weekly docs refresh

Mondays at 10:30 UTC, or on manual dispatch. Refreshes `README.md` and
`docs/*.md` against the repo's actual state by asking the local model (same
Qwen3.8 27B on loopback Ollama, via `opencode run --auto --agent build` with
the prompt in `.github/opencode/docs-refresh-prompt.md`) to read the git
history since the last refresh and update the docs to match.

The job checks out `main` cleanly (`fetch-depth: 0` for a real history),
asks the model to edit the docs in place, then commits and force-pushes
the running branch. There is no `git rebase -i origin/main` on a long
running branch as the previous implementation had — that conflicted on
nearly every second run because the running branch's docs and `main`'s
disagreed on the same hunks, and a conflict has no resolution strategy in
CI. Force-push from a clean checkout is the whole point of this rewrite.

`markdownlint README.md docs/*.md` runs once, after the model's work, and
is **advisory**, not a gate: a single stray violation does not kill the
run or open a follow-up model call to fix it. The pull request opens with
whatever the model produced and whatever the linter flagged, and a human
reviews the diff before merging. That is the right shape for a docs
refresh: the model is the one author, not a fixer, and the lint pass is
only there to make the diff visibly consistent.

The runner's `extraPackages` gained `markdownlint-cli` for this job. The
agent gets the same `nixos` MCP server (the `mcp-nixos` binary on the
runner's PATH) the fix agent has, so it can question its own memory of
upstream option names when writing `docs/MODULES.md` and
`docs/HOME-MANAGER.md`. The prompt tells it to fetch the current upstream
docs before linking an option it is not sure about, because a wrong option
name in a doc is worse than no link.

The pull request is opened on a dedicated `auto/doc-refresh` branch, force
pushed from each run. It is a separate branch from the weekly bump's
`automated/weekly-update`, so a docs change does not ride along with a
lock bump and vice-versa.

## Secrets

| Secret | Used by | What it is |
|---|---|---|
| `ATTIC_TOKEN` | `push-cache.yml` | push token for `attic.cyberfighter.space`, cache `main` |
| `CACHIX_AUTH_TOKEN` | `push-cache.yml` | push token for the `jdguillot` cachix cache |
| `PERSONAL_ACCESS_TOKEN` | `weekly-update.yml`, `docs-refresh.yml` | fine-grained PAT, contents + pull-requests write, so the weekly PRs trigger CI |

The triage and fix models need no secret at all: Ollama is on the runner
host's loopback and is unauthenticated there.
