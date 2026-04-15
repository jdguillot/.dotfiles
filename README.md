# NixOS dotfiles

Modular NixOS and Home Manager configuration with centralized host
metadata, reusable `cyberfighter.*` modules, and flake outputs for
local rebuilds and `deploy-rs`.

## Quick links

- `docs/MODULES.md` - full NixOS module reference
- `docs/HOME-MANAGER.md` - full Home Manager module reference
- `docs/SOPS-MIGRATION.md` - SOPS and secret workflows
- `hosts/templates/` - starter host configs
- `scripts/nixos-anywhere.sh` - bootstrap a new machine
- `scripts/generate_ssh_key.sh` - generate SSH keys for a host

## Repo layout

- `flake.nix` - Flake inputs and all `nixosConfigurations`,
  `homeConfigurations`, and `deploy.nodes` outputs
- `hosts/default.nix` - Source of truth for host metadata: profile,
  hostname, username
- `hosts/<host>/configuration.nix` - Per-host NixOS config
- `home/<user>/home.nix` - Per-user Home Manager config
- `modules/` - Reusable NixOS modules under the `cyberfighter`
  namespace
- `home/modules/` - Reusable Home Manager modules under the
  `cyberfighter` namespace
- `secrets/` - Encrypted secrets used by SOPS modules

## Flake outputs

### NixOS hosts

- `razer-nixos` (`hosts/razer-nixos/`)
  - Profile: `desktop`
  - Home: `cyberfighter@razer-nixos`
  - Deploy node: No
  - Main Niri workstation with GDM, gaming, Docker, Tailscale, PIA VPN,
    Flatpak, Cachix, TrueNAS mounts, 1Password, and Wine
- `sys-galp-nix` (`hosts/sys-galp-nix/`)
  - Profile: `desktop`
  - Home: `cyberfighter@sys-galp-nix`
  - Deploy node: Yes
  - Plasma 6 desktop with gaming, Bluetooth, SSH, Flatpak extras,
    SOPS, and Waydroid
- `nixos-portable` (`hosts/nixos-portable/`)
  - Profile: `desktop`
  - Home: None
  - Deploy node: No
  - Portable Plasma 6 desktop with Nvidia, gaming, Docker, PIA VPN,
    and SOPS
- `work-nix-wsl` (`hosts/work-wsl/`)
  - Profile: `wsl`
  - Home: `jdguillot@work-nix-wsl`
  - Deploy node: No
  - Work WSL config with VS Code server, Docker Desktop, custom CA
    bundle, Flatpak browsers/CAD, Tailscale, SSH, and SOPS
- `ryzn-nix-wsl` (`hosts/ryzn-wsl/`)
  - Profile: `wsl`
  - Home: `cyberfighter@ryzn-nix-wsl`
  - Deploy node: No
  - Personal WSL config with graphics, Docker, SSH, SOPS, and Cachix
- `thkpd-pve1` (`hosts/thkpd-pve1/`)
  - Profile: `minimal`
  - Home: `cyberfighter@thkpd-pve1`
  - Deploy node: Yes
  - Proxmox VE host with Docker, Tailscale, SSH, SOPS, and deployable
    system + home
- `simple-vm` (`hosts/simple-vm/`)
  - Profile: `minimal`
  - Home: `cyberfighter@simple-vm`
  - Deploy node: Yes
  - Minimal VM with SSH, Docker, Tailscale, and SOPS; deploys system
    only
- `vm-gameserver-nix` (`hosts/vm-gameserver-nix/`)
  - Profile: `minimal`
  - Home: `cyberfighter@vm-gameserver-nix` via `home/minimal`
  - Deploy node: Yes
  - Game server VM with Astroneer, scheduled Ludusavi backups,
    Tailscale, SOPS, and Playit service wiring

### Home Manager outputs

- `cyberfighter@razer-nixos`
- `cyberfighter@ryzn-nix-wsl`
- `cyberfighter@sys-galp-nix`
- `cyberfighter@thkpd-pve1`
- `cyberfighter@simple-vm`
- `cyberfighter@vm-gameserver-nix`
- `jdguillot@work-nix-wsl`

### deploy-rs nodes

- `thkpd-pve1`
- `simple-vm`
- `vm-gameserver-nix`
- `sys-galp-nix`

## NixOS modules

### Core option roots

These are the main roots used in `hosts/<host>/configuration.nix`:

- `cyberfighter.profile.enable` - Base profile defaults:
  `"desktop"`, `"wsl"`, `"minimal"`, `"none"`
- `cyberfighter.system.*` - Host identity and system defaults:
  `hostname`, `username`, `stateVersion`, `timeZone`, `locale`,
  `bootloader.*`, `extraGroups`, `wslOptions.*`
- `cyberfighter.nix.*` - Nix daemon, caches, GC, and extra `nix.conf`
  settings: `enableDevenv`, `trustedUsers`, `extraOptions`,
  `garbageCollect`, `optimize`
- `cyberfighter.packages.*` - Shared system package sets:
  `includeBase`, `includeDev`, `includeDesktop`, `includeVirt`,
  `extraPackages`
- `cyberfighter.filesystems.*` - CIFS/TrueNAS mounts and extra
  filesystems: `truenas.enable`, `truenas.server`, `truenas.mounts`,
  `smbCredentials`, `extraMounts`

### Profiles

- `desktop` - Enables desktop + graphics + sound, turns on Flatpak,
  includes base + desktop packages, and defaults to `systemd-boot`
- `wsl` - Enables graphics, keeps desktop packages off by default,
  disables `systemd-boot`, and leaves NetworkManager off by default
- `minimal` - Includes base packages, keeps desktop packages off,
  defaults to `systemd-boot`, and disables sleep/suspend/hibernate
  targets

### System features

Available under `cyberfighter.features.*`:

- `desktop` - Desktop environment, display manager, Firefox:
  `enable`, `environment`, `displayManager`, `firefox`
- `graphics` - Hardware acceleration and GPU drivers: `enable`,
  `nvidia.enable`, `nvidia.openDriver`, `nvidia.powerManagement`,
  `nvidia.prime.*`, `amd.enable`
- `sound` - PipeWire and audio defaults: `enable`
- `fonts` - Shared system fonts: `enable`
- `bluetooth` - Bluetooth support: `enable`
- `networking` - NetworkManager defaults: `networkmanager`
- `printing` - Printing support: `enable`
- `ssh` - OpenSSH server settings: `enable`, `passwordAuth`, `port`,
  `ports`, `permitRootLogin`
- `sops` - Host secret management: `enable`, `defaultSopsFile`,
  `sshKeyPaths`, `deployUserAgeKey`
- `docker` - Docker service and optional bootstrapped networks:
  `enable`, `rootless`, `enableOnBoot`, `networks`
- `tailscale` - Tailscale client setup: `enable`,
  `useRoutingFeatures`, `acceptRoutes`, `extraUpFlags`
- `vpn` - PIA VPN integration: `pia.enable`, `pia.autoConnect`,
  `pia.server`
- `flatpak` - Flathub and curated app bundles: `enable`, `browsers`,
  `cad`, `electronics`, `gaming`, `extraPackages`
- `gaming` - Steam and gaming defaults: `enable`
- `wine` - Wine support: `enable`
- `vscode` - VS Code system install: `enable`
- `onepassword` - 1Password desktop integration: `enable`
- `security` - Firejail sandboxing: `firejail`
- `cachix` - Cachix setup: `enable`
- `proxmox` - Proxmox VE node helpers: `enable`, `ipAddress`
- `gameserver` - Game server host support: `enable`, `ludusavi.*`,
  `astroneer.*`

## Home Manager modules

### Core home option roots

These are the main roots used in `home/<user>/home.nix`:

- `cyberfighter.profile.enable` - Home profile: `"desktop"`, `"wsl"`,
  `"minimal"`
- `cyberfighter.system.*` - User identity and state version:
  `username`, `homeDirectory`, `stateVersion`
- `cyberfighter.packages.*` - Shared user package sets: `includeDev`,
  `extraPackages`
- `cyberfighter.common.enable` - Shared base user config: Usually left
  enabled
- `cyberfighter.wsl.*` - WSL-specific Home Manager behavior:
  session/path helpers and Windows integration

### Home features

Available under `cyberfighter.features.*`:

- `git` - Git defaults plus personal/work includes: `enable`,
  `extraSettings`
- `shell` - Shared shell behavior and aliases: `enable`,
  `fish.enable`, `bash.enable`, `zsh.enable`, `starship.enable`,
  `extraSessionVariables`, `extraAliases`
- `editor` - Editors and editor-specific modules: `enable`, `vim.*`,
  `neovim.enable`, `vscode.*`, `lazyvim.enable`, `micro.enable`,
  `zed.enable`
- `terminal` - Terminal emulator modules: `enable`,
  `alacritty.enable`, `ghostty.enable`, `ghostty.fullscreen`
- `desktop` - User desktop apps: `enable`, `firefox.*`,
  `bitwarden.enable`, `extraPackages`
- `ssh` - SSH client config: `enable`, `onepass`, `hosts`
- `sops` - User secrets: `enable`
- `noctalia` - Noctalia shell integration: `enable`
- `tools` - CLI/TUI tools and helper packages: `enable`,
  `enableDefault`, `extraPackages`, `btop`, `copilotMcp`, `lazygit`,
  `mc`, `opencode`, `rofi`, `jujutsu`, `carapace`, `tmux`, `zellij`,
  `yazi`, `direnv`, `fastfetch`
- `tmuxinator` - Host-specific tmux layouts: `enable`

### Current home configs

- `home/cyberfighter` - Desktop-oriented setup with Fish + Zsh +
  Starship, Vim/Neovim/Zed/LazyVim, Alacritty + Ghostty, desktop apps,
  Noctalia, SSH host aliases, and admin/dev tools
- `home/jdguillot` - Work/WSL-oriented setup with Fish + Zsh +
  Starship, Neovim + LazyVim, Firefox, work Git include, SSH host
  aliases, and common CLI/TUI tools
- `home/minimal` - Lightweight server profile with Zsh + Starship,
  Vim/Neovim/LazyVim, SSH, and a small admin tool set

## How to use this repo

### Build or switch a NixOS host

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

### Deploy a remote host

```bash
deploy .#<hostname>
```

Use this only for hosts present under `deploy.nodes`.

### Inspect or update flake inputs

```bash
nix flake show
nix flake update
```

### Shell aliases used in this repo

- `ns` - rebuild system and current Home Manager config
- `hs` - switch the current Home Manager config
- `nb` - build boot generation and switch current Home Manager config
- `nu` - update flake inputs

### Practical notes

- New files must be tracked in git before `nixos-rebuild` or
  `home-manager switch`.
- Keep host metadata in `hosts/default.nix`; use host files for feature
  selection and overrides.
- For full option details, use `docs/MODULES.md` and `docs/HOME-MANAGER.md`.

## Adding or updating a host

1. Add the host entry to `hosts/default.nix`.
2. Create `hosts/<host>/configuration.nix`.
3. Add `hardware-configuration.nix` and/or `disk-config.nix` when needed.
4. Register the host in `flake.nix` under `nixosConfigurations`.
5. Add a Home Manager output in `flake.nix` if the host needs one.
6. Add a `deploy.nodes` entry if the host should be managed with `deploy-rs`.
7. Start from `hosts/templates/desktop-workstation.nix`,
   `gaming-rig.nix`, `minimal-server.nix`, or `wsl-dev.nix` when
   useful.

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
- Put shared host metadata in `hosts/default.nix`
- Use `scripts/nixos-anywhere.sh` when provisioning a fresh machine
- Use `scripts/generate_ssh_key.sh` when preparing SSH access for a new host
