# Hosts and templates

This page summarizes the current flake outputs, the folders they come from, the Home Manager targets attached to them, and the templates used to add new machines.

## Current hosts

| Host | Profile | Traits | Folder | Home config | `deploy-rs` | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `razer-nixos` | `desktop` | `dev` | `hosts/razer-nixos/` | `cyberfighter@razer-nixos` | no | Niri workstation with gaming, Docker, Flatpak, Cachix, SOPS, VPN, and TrueNAS mounts |
| `sys-galp-nix` | `desktop` | — | `hosts/sys-galp-nix/` | `cyberfighter@sys-galp-nix` | yes | Plasma 6 laptop with gaming, Bluetooth, Flatpak, SOPS, and Waydroid |
| `ryzn-server` | `desktop` | `dev` | `hosts/ryzn-server/` | `cyberfighter@ryzn-server` | yes | Plasma 6 workstation on an RTX 5090: local inference (Ollama + Hermes), ComfyUI container, gaming, lanzaboote Secure Boot, SOPS |
| `work-nix-wsl` | `wsl` | `dev` | `hosts/work-nix-wsl/` | `jdguillot@work-nix-wsl` | no | WSL with VS Code Server, Docker Desktop, Tailscale, SSH, and a SOPS-managed work CA |
| `thkpd-pve1` | `minimal` | — | `hosts/thkpd-pve1/` | `cyberfighter@thkpd-pve1` | yes | Proxmox VE host with bridge networking, Docker, Tailscale, and SOPS |
| `simple-vm` | `minimal` | — | `hosts/simple-vm/` | `cyberfighter@simple-vm` | yes (system only) | generic VM/server target with SSH, Docker, Tailscale, and SOPS |
| `vm-gameserver-nix` | `minimal` | — | `hosts/vm-gameserver-nix/` | `cyberfighter@vm-gameserver-nix` | yes | Astroneer server VM with Ludusavi, Playit, Tailscale, and SOPS |

## Traits

`traits` on a host's entry in `hosts/default.nix` names what the host is
*for* (currently just `dev`); `modules/core/traits/default.nix` turns
each entry into a `cyberfighter.traits.<name>` bool on both the system
and home side, and modules default their dev-flavored surfaces from it
(system dev packages, agent tooling, dev CLIs, full LazyVim). Either
side can override the bool to break the host/home symmetry.

## Naming notes

The flake output name is the name you use with `nixos-rebuild`, `home-manager`, `deploy`, and `nix flake show`. It is also the folder under `hosts/` and the value of `system.hostname` -- all three are the same string.

Examples:

```bash
sudo nixos-rebuild switch --flake .#work-nix-wsl
home-manager switch --flake .#jdguillot@work-nix-wsl
```

## Home configurations and deploy nodes

`flake.nix` derives `nixosConfigurations`, `homeConfigurations`, and
`deploy.nodes` from `hosts/default.nix` — the metadata's `home` field
names the folder under `home/` (or `null` for no home config; the
target is always `<username>@<hostname>`), and `deploy` is `null`,
`"system"`, or `"system+home"`. List the current outputs with
`nix flake show` rather than trusting any table here.

Examples:

```bash
deploy .#sys-galp-nix
deploy .#vm-gameserver-nix.home
deploy --dry-activate .#simple-vm
```

## Host templates

Templates live in `hosts/templates/`.

| Template | Best for | Notes |
| --- | --- | --- |
| `desktop-workstation.nix` | laptops and desktops | desktop profile with graphics, Flatpak, Docker, Tailscale, and SOPS |
| `gaming-rig.nix` | gaming desktops | desktop profile plus gaming and NVIDIA-oriented settings |
| `minimal-server.nix` | servers and VMs | minimal profile with SSH, Docker, Tailscale, and SOPS |
| `wsl-dev.nix` | WSL setups | WSL profile with graphics, Docker, Flatpak, and VS Code Server |

## Recommended onboarding flow

1. Pick the closest template in `hosts/templates/`.
2. Create `hosts/<name>/configuration.nix` and adjust only the host-specific values first.
3. Register the host in `hosts/default.nix` — including the `home` and `deploy` fields. That single entry drives `nixosConfigurations`, `homeConfigurations`, `deploy.nodes`, and the CI build matrix; there is nothing to add to `flake.nix` or the workflow.
4. If the host needs secrets or shared SSH aliases, run the `nixos-anywhere` helper with `--secrets`, `--ssh-host`, and one or more `--user` flags.
5. If the host needs a binary cache that CI does not already have (a CUDA-enabled package, say), add it to the nix configuration of the `ryzn-server` runner host itself. CI runs on that host's nix-daemon, so `modules/core/nix-settings` applies to the *built* hosts and has no effect on the build. See [`CI.md`](CI.md).
6. Update the host table at the top of this file and in the README.

## Provisioning example

```bash
./scripts/nixos-anywhere.sh \
  --hostname my-new-vm \
  --target root@192.168.1.50 \
  --hardware-config \
  --secrets \
  --ssh-host \
  --user cyberfighter
```

For more detail on local rebuilds, remote deployment, and first-time installs, see [`DEPLOYMENT.md`](DEPLOYMENT.md).
