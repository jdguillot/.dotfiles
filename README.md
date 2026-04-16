# NixOS dotfiles

Modular NixOS and Home Manager configurations for desktops, WSL machines, servers, and VMs, built around a small custom namespace: `cyberfighter.*`.

This flake tracks `nixos-unstable`, keeps a `nixos-25.11` package set available for selective use, and wires in shared building blocks such as `sops-nix`, `disko`, `deploy-rs`, `nixos-wsl`, `vscode-server`, `niri`, `proxmox-nixos`, and Noctalia.

## Documentation

Use the README for the quick overview, then jump into the focused docs as needed:

- [`docs/HOSTS.md`](docs/HOSTS.md) - exported hosts, templates, flake naming, and rollout notes
- [`docs/MODULES.md`](docs/MODULES.md) - NixOS/system module reference for `modules/`
- [`docs/HOME-MANAGER.md`](docs/HOME-MANAGER.md) - Home Manager module reference for `home/modules/`
- [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) - local rebuilds, `deploy-rs`, and `nixos-anywhere`
- [`docs/SOPS.md`](docs/SOPS.md) - system, home, and SSH-host secret workflows
- [`docs/RECOMMENDATIONS.md`](docs/RECOMMENDATIONS.md) - repo usage recommendations and the reasoning behind them

## Repository layout

```text
.
├── flake.nix
├── hosts/
│   ├── default.nix
│   └── templates/
├── home/
│   └── modules/
├── modules/
├── docs/
├── scripts/
└── secrets/
```

## Current hosts

| Host | Profile | Folder | Home config | `deploy-rs` | Notes |
| --- | --- | --- | --- | --- | --- |
| `razer-nixos` | `desktop` | `hosts/razer-nixos/` | `cyberfighter@razer-nixos` | no | Niri workstation with gaming, Docker, Flatpak, Cachix, SOPS, VPN, and TrueNAS mounts |
| `sys-galp-nix` | `desktop` | `hosts/sys-galp-nix/` | `cyberfighter@sys-galp-nix` | yes | Plasma 6 laptop with gaming, Bluetooth, Flatpak, SOPS, and Waydroid |
| `nixos-portable` | `desktop` | `hosts/nixos-portable/` | none | no | portable desktop profile with NVIDIA, gaming, Docker, VPN, and SOPS |
| `work-nix-wsl` | `wsl` | `hosts/work-wsl/` | `jdguillot@work-nix-wsl` | no | WSL with VS Code Server, Docker Desktop, Tailscale, SSH, and a SOPS-managed work CA |
| `ryzn-nix-wsl` | `wsl` | `hosts/ryzn-wsl/` | `cyberfighter@ryzn-nix-wsl` | no | WSL with Docker, Flatpak, SSH, Cachix, and SOPS |
| `thkpd-pve1` | `minimal` | `hosts/thkpd-pve1/` | `cyberfighter@thkpd-pve1` | yes | Proxmox VE host with bridge networking, Docker, Tailscale, and SOPS |
| `simple-vm` | `minimal` | `hosts/simple-vm/` | `cyberfighter@simple-vm` | yes (system only) | generic VM/server target with SSH, Docker, Tailscale, and SOPS |
| `vm-gameserver-nix` | `minimal` | `hosts/vm-gameserver-nix/` | `cyberfighter@vm-gameserver-nix` | yes | Astroneer game server with Ludusavi, Playit, Tailscale, and SOPS |

Two flake output names intentionally differ from their folders:

- `work-nix-wsl` uses `hosts/work-wsl/`
- `ryzn-nix-wsl` uses `hosts/ryzn-wsl/`

For more host detail and templates, see [`docs/HOSTS.md`](docs/HOSTS.md).

## NixOS module overview

System modules live in `modules/`.

### Core namespaces

- `cyberfighter.profile.enable` - host profile selector: `desktop`, `wsl`, `minimal`, or `none`
- `cyberfighter.system.*` - host identity, user, locale, timezone, bootloader, and platform metadata
- `cyberfighter.nix.*` - trusted users, GC, optimisation, substituters, and extra Nix settings
- `cyberfighter.packages.*` - shared system package bundles and extra packages
- `cyberfighter.filesystems.*` - TrueNAS/CIFS mounts and extra file systems

### Feature namespaces

Feature modules live under `cyberfighter.features.*` and currently cover:

- Desktop and hardware: `desktop`, `graphics`, `sound`, `fonts`, `bluetooth`, `printing`
- Connectivity and access: `networking`, `ssh`, `tailscale`, `vpn`
- Packaging and apps: `flatpak`, `cachix`, `onepassword`, `vscode`, `wine`
- Services and infra: `docker`, `security`, `sops`, `proxmox`
- Gaming and game hosting: `gaming`, `gameserver`, `gameserver.astroneer`

The most commonly used options in host files look like this:

```nix
{
  cyberfighter = {
    profile.enable = "desktop";

    system = {
      hostname = "my-host";
      username = "myuser";
      stateVersion = "25.05";
    };

    nix.trustedUsers = [ "root" "myuser" ];
    packages.includeDev = true;

    features = {
      desktop.environment = "plasma6";
      graphics.enable = true;
      docker.enable = true;
      tailscale.enable = true;
      sops.enable = true;
    };
  };
}
```

For the full option surface and upstream references, see [`docs/MODULES.md`](docs/MODULES.md).

## Home Manager module overview

Home modules live in `home/modules/` and use the same `cyberfighter.*` namespace style.

### Core home namespaces

- `cyberfighter.profile.enable` - home profile selector, usually set from `hostProfile`
- `cyberfighter.system.*` - username, home directory, and state version
- `cyberfighter.common.enable` - baseline shell and CLI setup
- `cyberfighter.packages.*` - shared user package bundles
- `cyberfighter.wsl.*` - Windows path integration and 1Password SSH-agent bridging for WSL

### Main feature groups

- `cyberfighter.features.git`, `shell`, `terminal`, `editor`, `desktop`, `ssh`, `sops`, `tools`, `noctalia`
- Shell submodules: `shell.zsh`, `shell.fish`, `shell.starship`
- Terminal submodules: `terminal.alacritty`, `terminal.ghostty`
- Editor submodules: `editor.lazyvim`, `editor.zed`, `editor.micro`
- Tool submodules: `tmux`, `zellij`, `yazi`, `btop`, `lazygit`, `jujutsu`, `carapace`, `direnv`, `rofi`, `sesh`, `fastfetch`, `opencode`, `mc`, `copilotMcp`

Example:

```nix
{
  cyberfighter = {
    profile.enable = hostProfile;

    system = {
      username = "myuser";
      homeDirectory = "/home/myuser";
      stateVersion = "24.11";
    };

    packages.includeDev = true;

    features = {
      ssh = {
        enable = true;
        onepass = true;
        hosts = [ "simple-vm" "thkpd-pve1" ];
      };

      shell.zsh.enable = true;
      editor.lazyvim.enable = true;
      terminal.ghostty.enable = true;
      tools.tmux.enable = true;
      tools.copilotMcp.enable = true;
    };
  };
}
```

For the detailed home reference, see [`docs/HOME-MANAGER.md`](docs/HOME-MANAGER.md).

## Common workflows

Inspect flake outputs:

```bash
nix flake show
```

Switch the local system:

```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

Switch only Home Manager:

```bash
home-manager switch --flake .#<user>@<hostname>
```

Test a system build without switching:

```bash
sudo nixos-rebuild test --flake .#<hostname>
```

Update flake inputs:

```bash
nix flake update
```

Useful aliases from the Home Manager shell module:

- `ns` - rebuild system and matching Home Manager target
- `hs` - switch Home Manager only
- `nu` - update flake inputs
- `nb` - build the flake output without switching

## Deployment

### `deploy-rs`

The flake exports deploy nodes for:

- `sys-galp-nix`
- `thkpd-pve1`
- `simple-vm`
- `vm-gameserver-nix`

Typical commands:

```bash
deploy .#sys-galp-nix
deploy .#vm-gameserver-nix.system
deploy --dry-activate .#thkpd-pve1
```

`simple-vm` is exported as a system-only node; the other deploy nodes have both `system` and `home` profiles.

### `nixos-anywhere`

For first-time installs, use `scripts/nixos-anywhere.sh` as the repo-aware wrapper around `nixos-anywhere`.

Example:

```bash
./scripts/nixos-anywhere.sh \
  --hostname simple-vm \
  --target root@192.168.1.50 -i ~/.ssh/bootstrap-key \
  --hardware-config \
  --secrets \
  --ssh-host \
  --user cyberfighter
```

The helper can:

- pass extra SSH flags after `--target`
- generate `hardware-configuration.nix`
- update `.sops.yaml` recipients and run `sops updatekeys`
- open `home/modules/features/ssh/ssh-hosts.yaml` for a new encrypted host entry
- add the host alias to one or more `home/<user>/home.nix` files
- seed host SSH keys from 1Password before installation

Use `hosts/templates/*.nix` as starting points for new machines. For more deployment detail, see [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md).

## Secrets

Secrets are managed with `sops-nix` on both the system and Home Manager sides.

Main secret locations in this repo:

- `secrets/secrets.yaml` - shared system/host secrets
- `secrets/secrets_common.yaml` - shared home/user secrets
- `home/modules/features/ssh/ssh-hosts.yaml` - encrypted SSH config snippets used by the Home Manager SSH module

The system SOPS wrapper also supports `deployUserAgeKey = true` for hosts that should derive a user-readable age key from the host SSH key during activation.

See [`docs/SOPS.md`](docs/SOPS.md) for practical examples and host-onboarding guidance.

## New host checklist

1. Start from a template in `hosts/templates/`.
2. Add host metadata to `hosts/default.nix`.
3. Create `hosts/<name>/configuration.nix`.
4. Export the host from `flake.nix` under `nixosConfigurations`.
5. Add a Home Manager target under `homeConfigurations` if needed.
6. Add a `deploy.nodes` entry if the host will be maintained remotely.
7. If the host uses secrets or shared SSH aliases, update SOPS/SSH data with `scripts/nixos-anywhere.sh` or the manual SOPS workflow.

## External references

- `deploy-rs`: <https://github.com/serokell/deploy-rs>
- `nixos-anywhere`: <https://github.com/nix-community/nixos-anywhere>
- `disko`: <https://github.com/nix-community/disko>
- `sops-nix`: <https://github.com/Mic92/sops-nix>
- NixOS manual: <https://nixos.org/manual/nixos/stable/>
- Home Manager manual: <https://nix-community.github.io/home-manager/>
- MyNixOS search: <https://mynixos.com/>
