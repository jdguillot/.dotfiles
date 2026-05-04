# NixOS dotfiles

Modular NixOS and Home Manager configurations for desktops, WSL
machines, Proxmox, and small server/VM targets. Hosts mostly declare
intent through the shared `cyberfighter.*` option namespace and let repo
modules translate that into upstream NixOS and Home Manager settings.

The flake follows `nixos-unstable`, keeps `nixos-25.11` available for
selected packages, and wires in shared tooling such as `sops-nix`,
`disko`, `deploy-rs`, `nixos-anywhere`, `nixos-wsl`, `vscode-server`,
`niri`, `proxmox-nixos`, `noctalia`, and `deptui`.

## Documentation

Use the README for the quick map, then jump into the focused docs:

- [`docs/HOSTS.md`](docs/HOSTS.md) - current hosts, flake outputs,
  templates, and onboarding flow
- [`docs/MODULES.md`](docs/MODULES.md) - NixOS module overview and
  namespace map
- [`docs/NIXOS-FEATURES.md`](docs/NIXOS-FEATURES.md) - detailed NixOS
  module and option reference
- [`docs/HOME-MANAGER.md`](docs/HOME-MANAGER.md) - Home Manager overview
  and integration notes
- [`docs/HOME-FEATURES.md`](docs/HOME-FEATURES.md) - detailed Home
  Manager feature reference
- [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) - local rebuilds,
  `deploy-rs`, and `nixos-anywhere`
- [`docs/SOPS.md`](docs/SOPS.md) - system, home, SSH-host, and
  bootstrap secret workflows
- [`docs/RECOMMENDATIONS.md`](docs/RECOMMENDATIONS.md) - repo
  recommendations and why they matter here

## Repository layout

```text
.
├── flake.nix
├── hosts/
│   ├── default.nix
│   └── templates/
├── home/
│   ├── <user>/home.nix
│   └── modules/
├── modules/
├── docs/
├── scripts/
└── secrets/
```

## Current hosts

- `razer-nixos` (`desktop`) - folder `hosts/razer-nixos/`; home
  `cyberfighter@razer-nixos`; `deploy-rs`: no. Niri workstation with
  gaming, Docker, PIA VPN, Flatpak, Cachix, SOPS, and TrueNAS mounts.
- `sys-galp-nix` (`desktop`) - folder `hosts/sys-galp-nix/`; home
  `cyberfighter@sys-galp-nix`; `deploy-rs`: yes. Plasma 6 laptop with
  gaming, Bluetooth, Flatpak, SOPS, SSH, and Waydroid.
- `nixos-portable` (`desktop`) - folder `hosts/nixos-portable/`; home
  none; `deploy-rs`: no. Portable Plasma/NVIDIA desktop profile with
  gaming, Docker, VPN, and SOPS.
- `work-nix-wsl` (`wsl`) - folder `hosts/work-wsl/`; home
  `jdguillot@work-nix-wsl`; `deploy-rs`: no. WSL with VS Code Server,
  Docker Desktop, Flatpak, Tailscale, SSH, and a SOPS-managed work CA
  bundle.
- `ryzn-nix-wsl` (`wsl`) - folder `hosts/ryzn-wsl/`; home
  `cyberfighter@ryzn-nix-wsl`; `deploy-rs`: no. WSL with graphics
  support, Docker, Flatpak, SSH, Cachix, and SOPS.
- `thkpd-pve1` (`minimal`) - folder `hosts/thkpd-pve1/`; home
  `cyberfighter@thkpd-pve1`; `deploy-rs`: yes. Proxmox VE host with
  bridge networking, Docker, Tailscale, and SOPS.
- `simple-vm` (`minimal`) - folder `hosts/simple-vm/`; home
  `cyberfighter@simple-vm`; `deploy-rs`: yes (system only). Generic
  VM/server target with SSH, Docker, Tailscale, and SOPS.
- `vm-gameserver-nix` (`minimal`) - folder
  `hosts/vm-gameserver-nix/`; home `cyberfighter@vm-gameserver-nix`;
  `deploy-rs`: yes. Astroneer server VM with Ludusavi backups, Playit,
  Tailscale, and SOPS.

Two flake output names intentionally differ from their folders:

- `work-nix-wsl` uses `hosts/work-wsl/`
- `ryzn-nix-wsl` uses `hosts/ryzn-wsl/`

For host details, templates, and rollout notes, see
[`docs/HOSTS.md`](docs/HOSTS.md).

## NixOS module overview

System modules live in `modules/`.

### Core and top-level namespaces

- `cyberfighter.profile.enable` - profile selector: `desktop`, `wsl`,
  `minimal`, or `none`
- `cyberfighter.system.*` - hostname, username, locale, timezone,
  state version, bootloader, and WSL metadata
- `cyberfighter.nix.*` - trusted users, substituters, GC, optimization,
  and extra `nix.conf` settings
- `cyberfighter.packages.*` - shared package bundles and extra packages
- `cyberfighter.filesystems.*` - TrueNAS/CIFS mounts and extra file systems

### Feature namespaces

Feature modules live under `cyberfighter.features.*` and currently cover:

- Desktop and hardware: `desktop`, `graphics`, `sound`, `fonts`,
  `bluetooth`, `printing`
- Connectivity and access: `networking`, `ssh`, `tailscale`, `vpn`
- Packaging and apps: `flatpak`, `cachix`, `onepassword`, `vscode`, `wine`
- Services and infrastructure: `docker`, `security`, `sops`, `proxmox`
- Gaming and hosting: `gaming`, `gameserver`

One host-level service lives outside the `cyberfighter.*` tree:

- `services.playit.*` - Playit tunnel agent used by `vm-gameserver-nix`

Common host shape:

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

See [`docs/MODULES.md`](docs/MODULES.md) for the overview and
[`docs/NIXOS-FEATURES.md`](docs/NIXOS-FEATURES.md) for the grouped
option reference.

## Home Manager overview

Home modules live in `home/modules/` and mirror the same `cyberfighter.*` style.

### Core home namespaces

- `cyberfighter.profile.enable` - home profile selector, usually set
  from `hostProfile`
- `cyberfighter.system.*` - username, home directory, and state version
- `cyberfighter.common.enable` - baseline shell, GitHub CLI, GPG,
  Catppuccin, and shared dotfile setup
- `cyberfighter.packages.*` - shared user package bundles
- `cyberfighter.wsl.*` - Windows-path integration and optional
  1Password SSH-agent bridging for WSL

### Main feature groups

- `cyberfighter.features.git`, `shell`, `terminal`, `editor`,
  `desktop`, `ssh`, `sops`, `tools`, `noctalia`
- Shell submodules: `bash`, `fish`, `zsh`, `starship`
- Terminal submodules: `terminal.alacritty`, `terminal.ghostty`
- Editor submodules: `editor.lazyvim`, `editor.zed`, `editor.micro`
- Tool submodules: `tmux`, `zellij`, `yazi`, `btop`, `lazygit`,
  `jujutsu`, `carapace`, `direnv`, `rofi`, `sesh`, `fastfetch`,
  `opencode`, `mc`, `copilotMcp`

Common home shape:

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

See [`docs/HOME-MANAGER.md`](docs/HOME-MANAGER.md) for the overview and
[`docs/HOME-FEATURES.md`](docs/HOME-FEATURES.md) for the detailed
option reference.

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

Build a Home Manager target without switching:

```bash
home-manager build --flake .#<user>@<hostname>
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

- `ns` - rebuild system and the matching Home Manager target
- `hs` - switch Home Manager only
- `nu` - update flake inputs
- `nb` - set the next boot generation and switch Home Manager

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

`simple-vm` is exported as a system-only node. The other deploy nodes
expose both `system` and `home` profiles. See
[`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) for the full deploy flow.

### `nixos-anywhere`

For first-time installs, use `scripts/nixos-anywhere.sh` as the
repo-aware wrapper around `nixos-anywhere`.

Example:

```bash
./scripts/nixos-anywhere.sh \
  --hostname simple-vm \
  --target root@192.168.1.50 -i ~/.ssh/bootstrap-key -p 2222 \
  --hardware-config \
  --secrets \
  --ssh-host \
  --user cyberfighter
```

The helper can:

- prompt for missing values or run non-interactively
- treat everything after `--target` as SSH flags until the next script flag
- generate `hardware-configuration.nix`
- update `.sops.yaml` recipients and run `sops updatekeys`
- open `home/modules/features/ssh/ssh-hosts.yaml` for a new encrypted host entry
- add the host alias to one or more `home/<user>/home.nix` files
- reuse or create host SSH keys in 1Password before installation

`--user` is repeatable and implies `--ssh-host`. For full setup notes,
see [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md).

## Secrets

Secrets are managed with `sops-nix` on both the system and Home Manager sides.

Main secret locations:

- `secrets/secrets.yaml` - shared system and host secrets
- `secrets/secrets_common.yaml` - shared home and identity secrets
- `home/modules/features/ssh/ssh-hosts.yaml` - encrypted SSH config
  snippets used by the Home Manager SSH module
- `hosts/work-wsl/100-PKROOTCA290-CA.yaml` - work CA bundle for `work-nix-wsl`

The system SOPS wrapper also supports `deployUserAgeKey = true` for
hosts that should derive a user-readable age key from the host SSH key
during activation.

For the working secret flow, see [`docs/SOPS.md`](docs/SOPS.md).

## New host checklist

1. Start from a template in `hosts/templates/`.
2. Add host metadata to `hosts/default.nix`.
3. Create `hosts/<name>/configuration.nix`.
4. Export the host from `flake.nix` under `nixosConfigurations`.
5. Add a Home Manager target under `homeConfigurations` if needed.
6. Add a `deploy.nodes` entry if the host will be maintained remotely.
7. If the host needs secrets or shared SSH aliases, update SOPS and SSH
   data with `scripts/nixos-anywhere.sh` or the manual SOPS workflow.
8. Track new Nix files before running a flake-based build, switch, or deploy.

## References

- `deploy-rs`: <https://github.com/serokell/deploy-rs>
- `nixos-anywhere`: <https://github.com/nix-community/nixos-anywhere>
- `disko`: <https://github.com/nix-community/disko>
- `sops-nix`: <https://github.com/Mic92/sops-nix>
- NixOS manual: <https://nixos.org/manual/nixos/stable/>
- Home Manager manual: <https://nix-community.github.io/home-manager/>
- Home Manager options:
  <https://nix-community.github.io/home-manager/options.xhtml>
- MyNixOS search: <https://mynixos.com/>
