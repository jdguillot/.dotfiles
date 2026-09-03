# Agent instructions — NixOS dotfiles

Modular NixOS + Home Manager flake. Hosts declare intent through the
shared `cyberfighter.*` option namespace and the modules translate that
into upstream NixOS/Home Manager settings.

**This is a public repo.** See "Security and privacy" below before
committing anything.

This file is the single source of truth for agent instructions;
`CLAUDE.md`, `GEMINI.md`, and `.github/copilot-instructions.md` are
pointers back here. Detailed references live in `docs/` — consult them
instead of guessing, and keep them current (see "Documentation"):

- `docs/HOSTS.md` — flake outputs, host folders, templates
- `docs/MODULES.md` — NixOS module reference for `modules/`
- `docs/HOME-MANAGER.md` — Home Manager modules in `home/modules/`
- `docs/DEPLOYMENT.md` — local rebuilds, `deploy-rs`, `nixos-anywhere`
- `docs/SOPS.md` — secrets workflows
- `docs/RECOMMENDATIONS.md` — repo conventions and their rationale

## Build, test, deploy

- **New files must be tracked in git before any build or switch** —
  flakes only see tracked files, and the failure mode (file silently
  missing from the eval) is confusing. `git add` first, always.
- Local system switch: `sudo nixos-rebuild switch --flake .#<hostname>`
- Test without creating a boot entry:
  `sudo nixos-rebuild test --flake .#<hostname>`
- Home Manager only: `home-manager switch --flake .#<user>@<hostname>`
- Interactive-shell aliases exist for the human workflow: `ns`
  (system + home), `hs` (home only), `nb` (boot + home), `nu` (flake
  update), `np` (npins update). Agents should use the full commands
  above.
- Build one host without activating (good pre-flight check):
  `nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel`
- Hostnames and users are centralized in `hosts/default.nix`; the flake
  outputs list every valid `<hostname>` and `<user>@<hostname>` target.
- Two lockfiles: `flake.lock` pins flake inputs (nixpkgs, home-manager,
  …); `npins/sources.json` pins vendored third-party sources (skill
  repos, pinned app trees) — update those with `npins update <name>`,
  never by hand-editing revs. New pins: `npins add github <owner> <repo>
  --branch <br>`, or declare by hand in `sources.json` (spec fields
  only, `null` revision/url/hash) and run `npins update <name>` to
  resolve. See `docs/RECOMMENDATIONS.md`.

### Build on hosts with horsepower

Check which machine you are on before building (`hostname`, and `nproc`
/ `free -h` if unsure). Laptops and WSL instances should not chew
through another host's desktop-sized closure. Two better options:

- Build/switch on the machine that owns the config when you are on it.
- Use `deploy-rs` for remote targets, with `--remote-build` when the
  destination is the beefier machine — the closure is then built on the
  target instead of being built locally and copied over:
  `deploy .#<hostname> --remote-build` (or `.#<hostname>.system` /
  `.#<hostname>.home` for a single profile). Nodes are declared in
  `deploy.nodes` in `flake.nix`; see `docs/DEPLOYMENT.md`.

### Scope your checks — don't `nix flake check` the whole repo

`nix flake check` evaluates deploy checks for every host, including ones
with much larger package sets, which wastes a lot of time for a
one-host change. Instead, build or eval only the host(s) you touched:

```bash
nix eval .#nixosConfigurations.<hostname>.config.system.build.toplevel.drvPath
```

Run the full check only when a change is genuinely cross-host (e.g.
`flake.nix`, `modules/core/`, or `hosts/default.nix`).

## Pattern: adding a new host

The attribute name in `hosts/default.nix`, the `system.hostname` value,
and the folder name under `hosts/` must all be the same string — the
flake and `.nixd-hosts.json` rely on that.

1. Add a metadata entry to `hosts/default.nix` (profile, hostname,
   username, stateVersion — never change stateVersion on an existing
   host — plus `home`: the folder under `home/` or `null`, and
   `deploy`: `null`, `"system"`, or `"system+home"`). `flake.nix` and
   the CI build matrix derive everything from this entry; there is no
   separate flake or workflow registration.
2. Create `hosts/<hostname>/configuration.nix`, starting from a
   template in `hosts/templates/`. Add `hardware-configuration.nix` and
   (for disko/nixos-anywhere installs) `disk-config.nix` as needed.
   Host-local service config files (compose files, native configs) live
   in this folder too.
3. For a brand-new machine, provision with `nixos-anywhere`
   (`scripts/nixos-anywhere.sh`, `docs/DEPLOYMENT.md`).
4. Update the host table in `README.md` and `docs/HOSTS.md`.

What a host is *for* is declared as `traits = [ "dev" ]` on its
`hosts/default.nix` entry; `modules/core/traits` exposes each as
`cyberfighter.traits.<name>` to both system and home modules, whose
dev-flavored defaults key off it. Don't add per-host/per-user enable
lines for things a trait already covers.

Host configs set `cyberfighter.*` options in one properly **nested**
attrset — do not flatten into repeated dotted paths:

```nix
{
  cyberfighter = {
    system.extraGroups = [ "docker" ];
    features = {
      docker.enable = true;
      tailscale.enable = true;
    };
  };
}
```

Profile and system identity (hostname, username, stateVersion) default
from the host's entry in `hosts/default.nix` — hosts set only what
deviates.

## Pattern: adding a new module

1. Create `modules/features/<name>/default.nix` (or a subfolder of an
   existing family like `modules/features/ai/`). Define options under
   `cyberfighter.features.<name>` using `lib.mkEnableOption` /
   `lib.mkOption`, and gate all config behind `lib.mkIf cfg.enable`.
2. Register the import in `modules/default.nix`.
3. Ship the service's config files in native format next to the module
   (see "Native config files" below); `modules/features/traefik/` is
   the reference example.
4. Home Manager modules follow the same shape under
   `home/modules/{core,features}/`, registered in
   `home/modules/default.nix`.
5. Add the module to `docs/MODULES.md` (or `docs/HOME-MANAGER.md`) and
   the README overview.

Core modules (`modules/core/`) are for things every host needs
(profiles, system identity, users, nix settings); features are opt-in.

## Configuration style

### Native config files over Nix-rendered options

Keep whole config files in their upstream format (`compose.yaml`,
`traefik.toml`, `litellm-config.yaml`, …) and wire them in from Nix.
Why: they map 1:1 to upstream docs, and the editor/LSP tooling for that
file type keeps working. Fill per-host values with
`pkgs.replaceVars ./file.toml { NAME = cfg.value; }` and `@NAME@`
placeholders — the build fails on a leftover or unused placeholder,
which catches drift. If only a couple of settings are needed, setting
them directly through Nix options is fine; whole config files should be
native.

### Services via docker compose, software via Nix

Prefer running services as docker compose projects (native
`compose.yaml` included through Nix, brought up by a systemd oneshot —
see the traefik module) rather than porting everything to
`services.*` NixOS options. Why: compose files track the service's own
docs and are portable. Installed software, on the other hand, should
come from Nix packages, not ad-hoc installs.

### Nix code style

- 2-space indentation, no tabs; Unix LF line endings only.
- Function parameters on separate lines; imports at the top.
- Use `lib.mkDefault` in profiles/modules so hosts can override; use
  `lib.mkEnableOption` for feature switches.
- Comments: 1–3 lines, facts and non-obvious constraints only — the
  "why" the code can't say itself. No history, no narrative, no
  restating the next line.

## Git workflow

- Commit as you go — small commits while iterating keep rollback points
  during rebuild/switch testing.
- Before pushing upstream, squash/rewrite the WIP commits into logical
  chunks of work. Ask before pushing.
- Commit messages follow conventional style seen in history:
  `feat(hosts): …`, `fix(secrets): …`, `docs(…): …`.
- Never include agent-session links or IDs in commit messages (e.g.
  `Claude-Session:` trailers pointing at a claude.ai session). A
  `Co-Authored-By` line is fine; session references are not.

## Security and privacy (public repo)

- No plaintext secrets, tokens, private hostnames, internal IPs, or
  emails in the repo. Secrets go through sops-nix (`secrets/`,
  `docs/SOPS.md`); private values reach configs via sops templates /
  dotenv interpolation at activation time, never at eval time.
- Before every commit, do a quick security pass over the diff: staged
  secrets, keys, internal URLs/hostnames, anything identifying.

## Documentation

When a change alters behavior, layout, hosts, or modules, update the
docs in the same change: the README (host table, overview) plus the
relevant `docs/*.md`. This file went stale once precisely because docs
weren't updated alongside the code — don't repeat that. Don't duplicate
volatile facts (host lists, module lists) into new places; link to the
single source instead.

## Working style

- **Teach while you work.** When summarizing changes for the user,
  explain *why* something was done a particular way, not just what
  changed — treat nontrivial decisions as teaching moments.
- **Fetch current docs before changing a service's settings.** Pull the
  service's latest upstream documentation (context7, web) before
  editing its config — defaults and recommendations move faster than
  training data.
- **Search GitHub issues when troubleshooting.** Before deep debugging,
  check the relevant project's issues (nixpkgs, NixOS-WSL, home-manager,
  the service itself) for the same symptom and any known fix or
  workaround.
