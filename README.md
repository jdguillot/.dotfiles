# NixOS dotfiles

Modular NixOS and Home Manager configuration built around a small set of host profiles, reusable feature modules, and flake outputs for local rebuilds or `deploy-rs`.

## Quick links

- `docs/MODULES.md` - full NixOS module reference
- `docs/HOME-MANAGER.md` - full Home Manager module reference
- `docs/SOPS-MIGRATION.md` - SOPS setup and secret workflows
- `hosts/templates/` - starter host configs (`desktop-workstation.nix`, `gaming-rig.nix`, `minimal-server.nix`, `wsl-dev.nix`)

## Repo layout

| Path | Purpose |
| --- | --- |
| `flake.nix` | Flake inputs and all `nixosConfigurations`, `homeConfigurations`, and `deploy.nodes` outputs |
| `hosts/default.nix` | Central host metadata: profile, hostname, username |
| `hosts/<host>/configuration.nix` | Per-host NixOS config |
| `home/<user>/home.nix` | Per-user Home Manager config |
| `modules/` | Reusable NixOS modules |
| `home/modules/` | Reusable Home Manager modules |
| `scripts/nixos-anywhere.sh` | Bootstrap new machines with nixos-anywhere |
| `scripts/generate_ssh_key.sh` | Generate SSH keys for new hosts |
| `secrets/` | Encrypted secrets managed with SOPS |

## Flake outputs in this repo

### NixOS hosts

| Flake output | Host dir | Profile | Home config | Deploy node | Notes |
| --- | --- | --- | --- | --- | --- |
| `razer-nixos` | `hosts/razer-nixos/` | `desktop` | `cyberfighter@razer-nixos` | No | Main desktop/laptop config with Niri, gaming, VPN, Flatpak, NAS mounts |
| `sys-galp-nix` | `hosts/sys-galp-nix/` | `desktop` | `cyberfighter@sys-galp-nix` | Yes | Plasma 6 desktop with Nvidia, gaming, Docker, PIA VPN |
| `nixos-portable` | `hosts/nixos-portable/` | `desktop` | None | No | Portable desktop config with Plasma 6, gaming, Flatpak, Waydroid |
| `work-nix-wsl` | `hosts/work-wsl/` | `wsl` | `jdguillot@work-nix-wsl` | No | Work WSL setup with VS Code server, Flatpak, Docker, SOPS |
| `ryzn-nix-wsl` | `hosts/ryzn-wsl/` | `wsl` | `cyberfighter@ryzn-nix-wsl` | No | Personal WSL setup with Docker, SOPS, Cachix |
| `thkpd-pve1` | `hosts/thkpd-pve1/` | `minimal` | `cyberfighter@thkpd-pve1` | Yes | Proxmox VE host with Docker, Tailscale, SOPS |
| `simple-vm` | `hosts/simple-vm/` | `minimal` | `cyberfighter@simple-vm` | Yes | Minimal VM with SSH, Docker, Tailscale, SOPS |
| `vm-gameserver-nix` | `hosts/vm-gameserver-nix/` | `minimal` | `cyberfighter@vm-gameserver-nix` via `home/minimal` | Yes | Game server VM with Astroneer, Ludusavi, Playit |

### Home Manager outputs

- `cyberfighter@razer-nixos`
- `jdguillot@work-nix-wsl`
- `cyberfighter@ryzn-nix-wsl`
- `cyberfighter@sys-galp-nix`
- `cyberfighter@thkpd-pve1`
- `cyberfighter@simple-vm`
- `cyberfighter@vm-gameserver-nix`

### deploy-rs nodes

- `thkpd-pve1`
- `simple-vm`
- `vm-gameserver-nix`
- `sys-galp-nix`

## NixOS modules

### Core namespaces

These are the main option roots used in `hosts/<host>/configuration.nix`:

| Option path | Purpose | Common values |
| --- | --- | --- |
| `cyberfighter.profile.enable` | Selects the base profile | `"desktop"`, `"wsl"`, `"minimal"`, `"none"` |
| `cyberfighter.system.*` | Host identity and system defaults | `hostname`, `username`, `stateVersion`, `timeZone`, `locale`, `bootloader.*`, `wslOptions.windowsUsername`, `extraGroups` |
| `cyberfighter.nix.*` | Nix daemon and cache behavior | `enableDevenv`, `trustedUsers`, `extraOptions`, `garbageCollect`, `optimize` |
| `cyberfighter.packages.*` | Shared package sets | `includeBase`, `includeDev`, `includeDesktop`, `includeVirt`, `extraPackages` |
| `cyberfighter.filesystems.*` | NAS and mount helpers | `truenas.enable`, `truenas.mounts`, `truenas.credentialsFile`, `truenas.host` |

### System feature modules

Available under `cyberfighter.features.*`:

| Feature | What it covers | Notable options |
| --- | --- | --- |
| `desktop` | Desktop session and browsers | `enable`, `environment`, `displayManager`, `firefox` |
| `graphics` | GPU drivers and hybrid graphics | `enable`, `nvidia.enable`, `nvidia.openDriver`, `nvidia.prime.*`, AMD support |
| `sound` | PipeWire and audio defaults | `enable` |
| `fonts` | Shared system fonts | `enable` |
| `networking` | NetworkManager defaults | `networkmanager` |
| `printing` | Printing support | `enable` |
| `ssh` | OpenSSH server settings | `enable`, `passwordAuth`, `port`, `ports`, `permitRootLogin` |
| `sops` | Host secrets and age key wiring | `enable`, `defaultSopsFile`, `sshKeyPaths`, `deployUserAgeKey` |
| `docker` | Docker service and networks | `enable`, rootless support, custom `networks` |
| `tailscale` | Tailscale client setup | `enable`, `useRoutingFeatures`, `acceptRoutes`, `extraUpFlags` |
| `vpn` | PIA VPN service | `pia.enable`, `pia.autoConnect`, `pia.server` |
| `flatpak` | Flatpak setup and app bundles | `enable`, `browsers`, `cad`, `extraPackages` |
| `gaming` | Steam and gaming tooling | `enable` and related Steam/gaming toggles |
| `wine` | Wine support | `enable` |
| `vscode` | VS Code installation | `enable` |
| `onepassword` | 1Password desktop integration | `enable` |
| `security` | Firejail sandboxing | `firejail` |
| `cachix` | Cachix auth and cache setup | `enable` |
| `proxmox` | Proxmox VE node config | `enable`, `ipAddress` |
| `gameserver` | Dedicated game server support | `enable`, `ludusavi.enable`, `astroneer.*` |

Profiles set sensible defaults:

- `desktop`: desktop, graphics, sound, Flatpak, base + desktop packages
- `wsl`: base packages, no systemd-boot, NetworkManager off by default
- `minimal`: base packages, short boot timeout, sleep/suspend disabled

## Home Manager modules

### Core namespaces

These are the main option roots used in `home/<user>/home.nix`:

| Option path | Purpose | Common values |
| --- | --- | --- |
| `cyberfighter.profile.enable` | Home profile, usually inherited from the host | `"desktop"`, `"wsl"`, `"minimal"` |
| `cyberfighter.system.*` | User identity and state version | `username`, `homeDirectory`, `stateVersion` |
| `cyberfighter.packages.*` | User package sets | `includeDev`, `extraPackages` |
| `cyberfighter.common.enable` | Shared defaults for all users | Usually left enabled |
| `cyberfighter.wsl.*` | WSL-specific HM settings | WSL helpers and path/session behavior |

### Home feature modules

Available under `cyberfighter.features.*`:

| Feature | What it covers | Notable options |
| --- | --- | --- |
| `git` | Git defaults and includes | identity and extra config |
| `shell` | Shared shell behavior | base aliases/env plus `fish.enable`, `zsh.enable`, `starship.enable` |
| `editor` | Editors and IDEs | `vim.enable`, `neovim.enable`, `micro.enable`, `zed.enable`, `lazyvim.enable` |
| `terminal` | Terminal emulators | `enable`, `alacritty.enable`, `ghostty.enable`, `ghostty.fullscreen` |
| `desktop` | User desktop apps | Firefox, Bitwarden, desktop package helpers |
| `ssh` | SSH client config | `enable`, `onepass`, `hosts` |
| `sops` | User secrets | SOPS-backed Home Manager secrets |
| `noctalia` | Noctalia shell integration | `enable` |
| `tools` | CLI/TUI extras | `btop`, `copilotMcp`, `lazygit`, `mc`, `opencode`, `rofi`, `jujutsu`, `carapace`, `tmux`, `zellij`, `yazi`, `direnv`, `fastfetch`, `sesh` |
| `tmuxinator` | Host-specific tmux session layouts | `enable` |

## Current user configs

### `home/cyberfighter`

- Desktop-oriented setup
- Fish + Zsh + Starship
- Vim, Neovim, Zed, LazyVim
- Alacritty and Ghostty
- Desktop apps, Bitwarden, Noctalia
- SSH host list for homelab machines
- Tooling such as tmux, zellij, yazi, lazygit, rofi, jujutsu

### `home/jdguillot`

- WSL/workstation-oriented setup
- Fish + Zsh + Starship
- Neovim + LazyVim
- Firefox and work git identity include
- SSH host list for work targets
- Tooling such as tmux, zellij, yazi, lazygit, direnv, midnight commander

### `home/minimal`

- Lightweight server/VM profile
- Zsh + Starship
- Vim, Neovim, LazyVim
- Small CLI tool set for admin tasks

## How to use this repo

### Build or switch a host

```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

Examples:

```bash
sudo nixos-rebuild switch --flake .#razer-nixos
sudo nixos-rebuild switch --flake .#sys-galp-nix
```

### Test a host without switching

```bash
sudo nixos-rebuild test --flake .#<hostname>
```

### Switch only Home Manager

```bash
home-manager switch --flake .#<user>@<host>
```

Examples:

```bash
home-manager switch --flake .#cyberfighter@razer-nixos
home-manager switch --flake .#jdguillot@work-nix-wsl
```

### Deploy with deploy-rs

```bash
deploy .#<hostname>
```

Use this for hosts that exist under `deploy.nodes`, currently:

- `thkpd-pve1`
- `simple-vm`
- `vm-gameserver-nix`
- `sys-galp-nix`

### Update flake inputs

```bash
nix flake update
```

If your shell aliases are loaded, this repo also expects:

- `ns` - rebuild system and home together
- `hs` - switch the current Home Manager config
- `nu` - update flake inputs

## Adding or updating a host

1. Add host metadata in `hosts/default.nix`.
2. Create `hosts/<host>/configuration.nix`.
3. Add `disk-config.nix` and/or `hardware-configuration.nix` when needed.
4. Register the host in `flake.nix` under `nixosConfigurations`.
5. Add a Home Manager output in `flake.nix` if the host needs one.
6. Add a `deploy.nodes` entry if the host should be managed with `deploy-rs`.
7. Use `hosts/templates/` as a starting point when possible.

Minimal host skeleton:

```nix
{
  imports = [ ../../modules ];

  cyberfighter = {
    profile.enable = "desktop";

    system = {
      hostname = "my-host";
      username = "my-user";
      stateVersion = "25.05";
    };

    features = {
      desktop.environment = "plasma6";
      docker.enable = true;
      sops.enable = true;
    };
  };
}
```

Important:

- Keep attributes nested under `cyberfighter = { ... };`
- New files must be tracked in git before `nixos-rebuild` or `home-manager switch`
- Put host metadata in `hosts/default.nix`; do not duplicate hostname/username logic across the tree

## Secrets and bootstrap notes

- System and Home Manager secrets live under `secrets/` and are wired through SOPS modules.
- `scripts/nixos-anywhere.sh` is the practical starting point for provisioning a new machine.
- If a host needs remote bootstrap plus declarative disks, pair `nixos-anywhere` with the host's `disk-config.nix`.
- For full secret setup details, use `docs/SOPS-MIGRATION.md`.
