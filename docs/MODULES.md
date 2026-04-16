# NixOS system modules

This repo's NixOS layer lives in `modules/`. Hosts mostly set `cyberfighter.*` options and let the modules translate those values into upstream NixOS settings.

## Namespace map

A small but important detail: not everything is under `cyberfighter.features.*`.

| Namespace | Purpose |
| --- | --- |
| `cyberfighter.profile.*` | system profile defaults |
| `cyberfighter.system.*` | host identity, locale, boot, and user metadata |
| `cyberfighter.nix.*` | Nix daemon and CLI settings |
| `cyberfighter.packages.*` | shared package bundles |
| `cyberfighter.filesystems.*` | TrueNAS/CIFS and extra file systems |
| `cyberfighter.features.*` | optional feature modules |

## Layout

```text
modules/
├── core/
│   ├── profiles/
│   ├── system/
│   ├── users/
│   └── nix-settings/
└── features/
    ├── 1password/
    ├── bluetooth/
    ├── cachix/
    ├── desktop/
    ├── docker/
    ├── filesystems/
    ├── flatpak/
    ├── fonts/
    ├── gameserver/
    ├── gaming/
    ├── graphics/
    ├── networking/
    ├── packages/
    ├── printing/
    ├── proxmox/
    ├── security/
    ├── sops/
    ├── sound/
    ├── ssh/
    ├── tailscale/
    ├── vpn/
    ├── vscode/
    └── wine/
```

## Profile defaults

`cyberfighter.profile.enable` accepts `desktop`, `wsl`, `minimal`, or `none`.

| Profile | Defaults applied |
| --- | --- |
| `desktop` | enables `features.desktop`, `graphics`, `sound`; sets `networking.networkmanager = true`; enables Flatpak with a small default package set; enables `packages.includeBase` and `packages.includeDesktop`; defaults to `systemd-boot` |
| `wsl` | keeps graphics support on, defaults `networking.networkmanager = false`, leaves desktop package bundles off, and disables `systemd-boot` |
| `minimal` | keeps package defaults lean, defaults `networking.networkmanager = true`, keeps desktop packages off, enables `systemd-boot`, and disables sleep/hibernate targets |
| `none` | applies no bundled defaults |

## Core and top-level modules

### `cyberfighter.profile`

- `cyberfighter.profile.enable`

See the profile table above for what each value turns on by default.

### `cyberfighter.system`

Used by every host for shared system metadata.

Key options:

- `cyberfighter.system.hostname`
- `cyberfighter.system.username`
- `cyberfighter.system.userDescription`
- `cyberfighter.system.extraGroups`
- `cyberfighter.system.timeZone`
- `cyberfighter.system.locale`
- `cyberfighter.system.stateVersion`
- `cyberfighter.system.bootloader.systemd-boot`
- `cyberfighter.system.bootloader.efiCanTouchVariables`
- `cyberfighter.system.bootloader.luksDevice`
- `cyberfighter.system.windowsUsername`

Upstream references:

- NixOS boot options: <https://mynixos.com/search?q=boot.loader>
- NixOS user options: <https://mynixos.com/search?q=users.users>

### `cyberfighter.nix`

Repo-level Nix settings, including the shared substituters used here.

Key options:

- `cyberfighter.nix.enableDevenv`
- `cyberfighter.nix.trustedUsers`
- `cyberfighter.nix.keepOutputs`
- `cyberfighter.nix.keepDerivations`
- `cyberfighter.nix.extraOptions`
- `cyberfighter.nix.garbageCollect`
- `cyberfighter.nix.optimize`

Notes:

- When `enableDevenv = true`, the module enables the Cachix/substituter set used by this repo, including `devenv`, `jdguillot`, `nix-community`, `niri`, `noctalia`, and `proxmox-nixos` caches.
- The module also creates a SOPS-backed GitHub access-token include for `nix.conf`.

Upstream references:

- Nix settings: <https://nix.dev/manual/nix/stable/command-ref/conf-file>
- MyNixOS Nix search: <https://mynixos.com/search?q=nix.settings>

### `cyberfighter.packages`

Shared package bundles that profiles and hosts can mix and match.

Key options:

- `cyberfighter.packages.includeBase`
- `cyberfighter.packages.includeDev`
- `cyberfighter.packages.includeDesktop`
- `cyberfighter.packages.includeVirt`
- `cyberfighter.packages.extraPackages`

Notes:

- `includeBase` is the gate for the combined package list and the `trash-empty` systemd service.
- Development packages include tooling such as `deploy-rs`, `github-copilot-cli`, `claude-code`, `nixd`, language servers, and Node tooling.
- Desktop packages include `kitty`, `wofi`, `bitwarden-desktop`, and `1Password` GUI packages.

Upstream references:

- Environment packages: <https://mynixos.com/search?q=environment.systemPackages>
- Systemd services: <https://mynixos.com/search?q=systemd.services>

### `cyberfighter.filesystems`

Top-level file system helpers, especially for TrueNAS/CIFS mounts.

Key options:

- `cyberfighter.filesystems.truenas.enable`
- `cyberfighter.filesystems.truenas.server`
- `cyberfighter.filesystems.truenas.mounts`
- `cyberfighter.filesystems.smbCredentials`
- `cyberfighter.filesystems.extraMounts`

Notes:

- When TrueNAS mounts are enabled, the module creates SMB username/password secrets and renders `/etc/nixos/smb-secrets` through `sops-nix`.
- The repo's `razer-nixos` host uses this for personal share mounts.

Upstream references:

- NixOS file systems: <https://mynixos.com/search?q=fileSystems>
- CIFS mount options: <https://nixos.org/manual/nixos/stable/#sec-file-systems>

Example:

```nix
{
  cyberfighter.filesystems.truenas = {
    enable = true;
    server = "truenas.example.internal";
    mounts.home = {
      share = "userdata/myuser";
      mountPoint = "/mnt/truenas-home";
    };
  };
}
```

## Feature modules

### Desktop and hardware

| Module | Main options | Notes | Upstream refs |
| --- | --- | --- | --- |
| `desktop` | `enable`, `environment`, `displayManager`, `firefox` | supports `plasma6`, `plasma5`, `gnome`, `hyprland`, `niri`, or `none`; current hosts use `plasma6` and `niri` | <https://mynixos.com/search?q=services.desktopManager> |
| `graphics` | `enable`, `nvidia.enable`, `nvidia.prime.enable`, `nvidia.prime.intelBusId`, `nvidia.prime.nvidiaBusId`, `nvidia.powerManagement`, `nvidia.openDriver`, `amd.enable` | GPU acceleration and vendor-specific tuning | <https://mynixos.com/search?q=hardware.nvidia> |
| `sound` | `enable` | PipeWire-based sound stack | <https://mynixos.com/search?q=services.pipewire.enable> |
| `fonts` | `enable` | common programming and desktop font packages | <https://mynixos.com/search?q=fonts.packages> |
| `bluetooth` | `enable`, `powerOnBoot`, `extraPackages` | Bluetooth stack and helper tools | <https://mynixos.com/search?q=hardware.bluetooth.enable> |
| `printing` | `enable` | CUPS printing | <https://mynixos.com/search?q=services.printing.enable> |

### Networking and access

| Module | Main options | Notes | Upstream refs |
| --- | --- | --- | --- |
| `networking` | `networkmanager` | thin wrapper around NetworkManager enablement | <https://mynixos.com/search?q=networking.networkmanager.enable> |
| `ssh` | `enable`, `ports`, `passwordAuth`, `permitRootLogin`, `authorizedKeys` | OpenSSH server settings | <https://mynixos.com/search?q=services.openssh.enable> |
| `tailscale` | `enable`, `useRoutingFeatures`, `acceptRoutes`, `extraUpFlags` | client and routing flags | <https://mynixos.com/search?q=services.tailscale.enable> |
| `vpn.pia` | `enable`, `autoStart`, `server`, `port`, `credentialsFile` | PIA/OpenVPN workflow; expects SOPS when credentials are secret-backed | <https://mynixos.com/search?q=services.openvpn.servers> |

### Packaging and applications

| Module | Main options | Notes | Upstream refs |
| --- | --- | --- | --- |
| `flatpak` | `enable`, `browsers`, `cad`, `electronics`, `gaming`, `extraPackages` | wraps `nix-flatpak` with category toggles | <https://mynixos.com/search?q=services.flatpak> |
| `cachix` | `enable` | turns on repo Cachix integration; asserts SOPS is enabled | <https://mynixos.com/search?q=nix.settings.substituters> |
| `onepassword` | `enable` | system-side 1Password integration | <https://mynixos.com/search?q=1password> |
| `vscode` | `enable` | system package integration for VS Code | <https://mynixos.com/search?q=vscode> |
| `wine` | `enable` | Wine support for Windows apps | <https://mynixos.com/search?q=wine> |

### Services and infrastructure

| Module | Main options | Notes | Upstream refs |
| --- | --- | --- | --- |
| `docker` | `enable`, `rootless`, `enableOnBoot`, `networks` | Docker engine plus optional named bridge networks | <https://mynixos.com/search?q=virtualisation.docker.enable> |
| `security` | `firejail` | lightweight sandboxing toggle | <https://mynixos.com/search?q=programs.firejail.enable> |
| `sops` | `enable`, `defaultSopsFile`, `sshKeyPath`, `deployUserAgeKey` | wraps `sops-nix`; can derive a user age key from the host SSH key | <https://github.com/Mic92/sops-nix> |
| `proxmox` | `enable`, `ipAddress` | Proxmox VE integration via `proxmox-nixos` | <https://github.com/SaumonNet/proxmox-nixos> |

### Gaming and game hosting

| Module | Main options | Notes | Upstream refs |
| --- | --- | --- | --- |
| `gaming` | `enable`, `steam.enable`, `steam.remotePlay`, `steam.localNetworkGameTransfers`, `steam.gamescopeSession`, `gamemode`, `mangohud`, `protonup`, `extraPackages` | desktop gaming stack | <https://mynixos.com/search?q=programs.steam.enable> |
| `gameserver` | `enable`, `ludusavi.enable`, `ludusavi.schedule`, `ludusavi.path`, `ludusavi.games`, `ludusavi.roots`, `ludusavi.customGames` | backup-aware game server plumbing | <https://mynixos.com/search?q=systemd.timers> |
| `gameserver.astroneer` | `enable`, `serverName`, `gamePort`, `maxPlayers`, `autoSaveInterval`, `openFirewall`, `publicIpFile`, `serverPasswordFile` | AstroTuxLauncher-based Astroneer server | <https://github.com/CreeperHost/AstroTuxLauncher> |
| `gameserver.playit` | `enable`, `package`, `secretPath` | Playit tunnel helper module; note that `vm-gameserver-nix` currently uses `services.playit` directly in the host config | <https://mynixos.com/search?q=playit> |

## Practical examples

### Desktop host

```nix
{
  cyberfighter = {
    profile.enable = "desktop";

    system = {
      hostname = "my-desktop";
      username = "myuser";
      stateVersion = "25.05";
    };

    nix.trustedUsers = [ "root" "myuser" ];
    packages.includeDev = true;

    features = {
      desktop = {
        environment = "plasma6";
        firefox = true;
      };

      graphics.enable = true;
      docker.enable = true;
      tailscale.enable = true;

      sops = {
        enable = true;
        defaultSopsFile = ../../secrets/secrets.yaml;
      };
    };
  };
}
```

### Minimal server

```nix
{
  cyberfighter = {
    profile.enable = "minimal";

    system = {
      hostname = "my-server";
      username = "myuser";
      stateVersion = "25.11";
    };

    features = {
      ssh = {
        enable = true;
        passwordAuth = false;
        permitRootLogin = "no";
      };

      docker.enable = true;
      tailscale.enable = true;
      sops.enable = true;
    };
  };
}
```

### Astroneer game server

```nix
{
  cyberfighter.features.gameserver = {
    enable = true;
    ludusavi.enable = true;

    astroneer = {
      enable = true;
      serverName = "my-astroneer-server";
      gamePort = 10806;
      maxPlayers = 8;
      openFirewall = true;
      publicIpFile = config.sops.secrets."playit-tunnel-ip".path;
      serverPasswordFile = config.sops.secrets."astroneer-server-password".path;
    };
  };
}
```

## Where to set things

- Put host-specific values in `hosts/<name>/configuration.nix`
- Keep reusable behaviour in `modules/`
- Register metadata in `hosts/default.nix`
- Export hosts and deploy nodes from `flake.nix`

For host-level examples, see [`HOSTS.md`](HOSTS.md). For deployment and first-time installs, see [`DEPLOYMENT.md`](DEPLOYMENT.md).
