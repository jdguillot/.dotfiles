# Hosts and templates

This page summarizes the current flake outputs, the folders they come from, the Home Manager targets attached to them, and the templates used to add new machines.

## Current hosts

| Host | Profile | Folder | Home config | `deploy-rs` | Notes |
| --- | --- | --- | --- | --- | --- |
| `razer-nixos` | `desktop` | `hosts/razer-nixos/` | `cyberfighter@razer-nixos` | no | Niri workstation with gaming, Docker, Flatpak, Cachix, SOPS, VPN, and TrueNAS mounts |
| `sys-galp-nix` | `desktop` | `hosts/sys-galp-nix/` | `cyberfighter@sys-galp-nix` | yes | Plasma 6 laptop with gaming, Bluetooth, Flatpak, SOPS, and Waydroid |
| `ryzn-server` | `desktop` | `hosts/ryzn-server/` | `cyberfighter@ryzn-server` | yes | Plasma 6 workstation on an RTX 5090: local inference (Ollama + Hermes), ComfyUI container, gaming, lanzaboote Secure Boot, SOPS |
| `work-nix-wsl` | `wsl` | `hosts/work-nix-wsl/` | `jdguillot@work-nix-wsl` | no | WSL with VS Code Server, Docker Desktop, Tailscale, SSH, and a SOPS-managed work CA |
| `thkpd-pve1` | `minimal` | `hosts/thkpd-pve1/` | `cyberfighter@thkpd-pve1` | yes | Proxmox VE host with bridge networking, Docker, Tailscale, and SOPS |
| `simple-vm` | `minimal` | `hosts/simple-vm/` | `cyberfighter@simple-vm` | yes (system only) | generic VM/server target with SSH, Docker, Tailscale, and SOPS |
| `vm-gameserver-nix` | `minimal` | `hosts/vm-gameserver-nix/` | `cyberfighter@vm-gameserver-nix` | yes | Astroneer server VM with Ludusavi, Playit, Tailscale, and SOPS |

## Naming notes

The flake output name is the name you use with `nixos-rebuild`, `home-manager`, `deploy`, and `nix flake show`. It is also the folder under `hosts/` and the value of `system.hostname` -- all three are the same string.

Examples:

```bash
sudo nixos-rebuild switch --flake .#work-nix-wsl
home-manager switch --flake .#jdguillot@work-nix-wsl
```

## Home configurations

The flake currently exports these Home Manager targets:

- `cyberfighter@razer-nixos`
- `jdguillot@work-nix-wsl`
- `cyberfighter@ryzn-nix-wsl`
- `cyberfighter@sys-galp-nix`
- `cyberfighter@thkpd-pve1`
- `cyberfighter@simple-vm`
- `cyberfighter@vm-gameserver-nix`

`nixos-portable` does not currently export a Home Manager target from `flake.nix`.

## Deploy nodes

`deploy-rs` is configured for four hosts:

| Deploy node | Profiles |
| --- | --- |
| `sys-galp-nix` | `system`, `home` |
| `thkpd-pve1` | `system`, `home` |
| `vm-gameserver-nix` | `system`, `home` |
| `simple-vm` | `system` only |

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
3. Register the host in `hosts/default.nix` so `flake.nix` can reuse the shared host metadata.
4. Add the host to `flake.nix` under `nixosConfigurations`.
5. Add a Home Manager output if the machine should get one.
6. Add a `deploy.nodes` entry if the machine will be updated remotely.
7. If the host needs secrets or shared SSH aliases, run the `nixos-anywhere` helper with `--secrets`, `--ssh-host`, and one or more `--user` flags.
8. **Add the host to the build matrix in `.github/workflows/cachix.yml`.** The matrix is a hand-maintained copy of `nixosConfigurations`, and nothing checks that the two agree. A host missing from it is silently never built by CI; a host left in it after being removed fails the job with a confusing eval error. Update the table at the top of this file at the same time.
9. If the host needs a binary cache that CI does not already have (a CUDA-enabled package, say), add it to the `extra-conf` of the build job too. `modules/core/nix-settings` configures the nix daemon *on the built hosts* -- it has no effect on the runner performing the build.

Steps 8 and 9 are the ones that rot quietly: everything still works locally, and only CI is wrong.

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
