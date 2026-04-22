# Repository recommendations

These are practical recommendations for working in this repo, along with the reasons they pay off.

| Recommendation | Why |
| --- | --- |
| Keep host metadata in `hosts/default.nix` and consume it from `flake.nix` helpers. | It keeps hostname, username, and profile data in one place and avoids repeating that data across `nixosConfigurations`, `homeConfigurations`, and `deploy.nodes`. |
| Start new hosts from `hosts/templates/*.nix`. | The templates already match this repo's module structure and keep new machines aligned with the `cyberfighter.*` option surface. |
| Prefer profile defaults plus targeted overrides instead of flattening everything into each host. | The `desktop`, `wsl`, and `minimal` profiles already provide good defaults; keeping host files focused on exceptions makes them easier to maintain. |
| Use `cyberfighter.packages.*` and `cyberfighter.features.*` first, then fall back to raw upstream options only when needed. | That keeps the repo consistent and makes the docs, templates, and future refactors more reliable. |
| Keep secrets in SOPS-managed files and avoid plain-text host-specific secret sprawl. | The repo is already wired for `sops-nix` on both the system and Home Manager sides, so following that path reduces one-off secret handling. |
| Use `home/modules/features/ssh/ssh-hosts.yaml` for shared SSH aliases that multiple users or machines should consume. | It keeps SSH snippets encrypted, shareable, and centrally managed instead of scattering them across `~/.ssh/config` fragments. |
| Use `scripts/nixos-anywhere.sh` for new-host rollouts when the machine needs secrets or SSH alias wiring. | The helper already handles SSH key seeding, recipient updates, `ssh-hosts.yaml`, and Home Manager host-list updates, so it saves manual follow-up work. |
| Add `deploy.nodes` for remotely managed machines and keep system-only vs system-plus-home explicit. | It makes remote updates predictable and avoids assuming every host has a Home Manager profile. |
| Track new Nix files before evaluating the flake for a switch or deploy. | Flake-based builds only see tracked files, so untracked host/module files are a common source of confusing evaluation failures. |
| Keep README high-level and push detailed option docs into `docs/`. | The repo already has enough modules and hosts that the README works best as an entry point, while the deeper docs stay focused and easier to update. |
| Update docs whenever a module adds a new option or a helper script changes its interface. | This repo relies on a small custom option surface and helper scripts; keeping docs close to the code prevents drift and makes new-host setup much smoother. |
