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
`opencode` and `curl`.

Adding a tool there does nothing until `ryzn-server` is rebuilt, and the
failure that follows is opaque — `jq: command not found` partway through
some script, with nothing connecting it to a pending `nixos-rebuild`. The
bump workflow's jobs therefore open with
`.github/scripts/preflight.sh <tools…>`, which names what is missing and
what to run:

```bash
deploy .#ryzn-server.system --remote-build
```

## `cachix.yml` — build and cache

Triggered by pushes to `main`, by pull requests, and weekly on Sundays.

```
                ┌─> build (matrix, one per host) ─┬─> deploy-checks
flake-check ────┤                                 │
                └─> home  (matrix, one per home) ─┴─> push
```

- **flake-check** runs `nix flake check --no-build` and emits the host list,
  read straight out of the flake. A host added to `hosts/default.nix` joins
  the build matrix with no workflow edit.
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
- **deploy-checks** builds `checks.x86_64-linux.{deploy-schema,deploy-activate}`
  once the matrix has the toplevels those depend on. It runs only when every
  host built; a missing toplevel would fail the activation check for a reason
  that has nothing to do with the deploy config.
- **push** calls the reusable `push-cache.yml` with whatever artifacts exist.
  Hosts that failed simply have no artifact, so a partial run pushes the
  hosts that worked and names the ones it skipped in the job summary.

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

- The push job requires `needs.flake-check.result == 'success'`. A skipped
  `needs` still satisfies `!cancelled()`, so without that explicit assertion
  a failed evaluation would fall straight through to a push.
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

## `update-flake-lock.yml` — the weekly bump

Tuesdays at 05:00 UTC, or on manual dispatch. Dependabot cannot do this:
`.github/dependabot.yml` only understands `github-actions`, so without this
workflow `flake.lock` and `npins/sources.json` move only by hand.

```
scan ──> update ──> cache ──> pr
```

### scan — look before updating

`.github/scripts/collect-upstream-signal.sh` walks every direct flake input
and every npins pin and asks GitHub, per source, what landed since the
currently pinned revision and which issues and pull requests were touched in
that window. Direct inputs only: transitive nodes are pinned by their own
flakes and move when the direct input moves, so holding one back means
nothing. The tracked branch or tag comes from the lock's `original` field,
never `locked` — half these inputs pin one (`nixos-25.11`, `legacy-v4`,
`stable`, `v1.1.0`), and comparing those against `HEAD` would diff them
against master.

`.github/scripts/scan-verdict.sh` hands that digest to the local model on
this host's loopback Ollama and gets back a list of inputs to hold at their
current revision. It is a plain `curl`, not an agent: the job is one
judgement over one bounded document, and Ollama's JSON-schema constrained
decoding makes the answer parseable by construction. The prompt is
`.github/opencode/scan-prompt.md`.

The step **fails open**. A hold list is advice; the flake check and the
per-host builds are the actual gate, so an unreachable model or a garbled
answer must not stall the week's bump. It records `degraded: true` and
proceeds with no holds.

### update — apply, prove, and adapt

`.github/scripts/apply-updates.sh` runs `nix flake update` and `npins update`
with an explicit name list, so a hold is a real hold — that input keeps its
revision while everything around it moves. Inputs that `follows` nixpkgs
still move with nixpkgs; holding those back would mean holding nixpkgs.

`.github/scripts/check-and-build.sh` then runs `nix flake check --no-build`
and builds every host and every standalone home configuration, sequentially
rather than as a matrix: the fix step
below needs the failing tree and the failing log in one workspace, and a
matrix job cannot hand its working tree to the next job. It builds every host
even after one fails, so a single run surfaces every breakage the bump
caused.

If that fails, `opencode run --auto` gets the failure log and
`.github/opencode/fix-prompt.md`, and tries to adapt the repo to whatever
upstream renamed. It is told not to touch the lock files — reverting the bump
is not a fix — and to write what it did to `fix-notes.md`, which becomes part
of the pull request body. Then the check and build run again.

The attempt is bounded: `fix-timeout-minutes` (default 30, raisable on a
manual dispatch) is both a `timeout` around the run and a line in the prompt,
so the agent can wind down and write its notes rather than only being killed.
The failure mode being guarded against is not a wrong edit -- a wrong edit
fails the re-check and no pull request opens -- but *no* edit: an agent
chasing a bad hypothesis holds the concurrency group and the GPU indefinitely.
On a timeout the step appends a note saying so, so the agent's own account and
the fact it was cut off both reach the pull request body.

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

The job is green only if the flake checked and **every** host built, before
or after that fix. Nothing downstream runs otherwise, so a week that cannot
be made to work ends with a failed run and a summary rather than a pull
request.

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

That is the whole reason the transcript can go to a public log: there is
nothing in the agent's reach that is not already published. If that stops
being true — a secret widened to a group the runner is in, a job that hands
it a real credential — the transcript has to stop being printed before the
secret is added, not after.

### How the bump has to be applied

`nix flake check` runs with `--show-trace`; the per-host `nix build` calls do
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

The cache push is the same reusable workflow `cachix.yml` uses, so the
closure is already in `attic` and `cachix` before anyone reads the PR — a
switch on the other machines pulls rather than builds. The PR job waits for
it but does not require it; a cache hiccup should not cost the week its pull
request, and the body says so if the push did not succeed.

The branch is pushed from the **update** job, not the PR job, because the
agent's fix lives in that working tree and only that job has it. A branch
push is not a pull request, and it only happens once the tree is green.

The PR is opened with `PERSONAL_ACCESS_TOKEN` where it exists. A pull request
opened with the default `GITHUB_TOKEN` does not trigger other workflows —
GitHub suppresses that to avoid recursive runs — so `cachix.yml` would never
post a status on it. The builds in the update job already proved the tree;
the PAT is so the PR visibly shows it.

Manual dispatch takes a `skip-scan` input that bumps everything without the
triage pass.

## Secrets

| Secret | Used by | What it is |
|---|---|---|
| `ATTIC_TOKEN` | `push-cache.yml` | push token for `attic.cyberfighter.space`, cache `main` |
| `CACHIX_AUTH_TOKEN` | `push-cache.yml` | push token for the `jdguillot` cachix cache |
| `PERSONAL_ACCESS_TOKEN` | `update-flake-lock.yml` | fine-grained PAT, contents + pull-requests write, so the weekly PR triggers CI |

The triage and fix models need no secret at all: Ollama is on the runner
host's loopback and is unauthenticated there.
