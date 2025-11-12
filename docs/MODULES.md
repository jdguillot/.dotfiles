# NixOS System Modules - Complete Reference

This document provides complete documentation for all NixOS system modules in this configuration.

## Table of Contents

- [Host Registration System](#host-registration-system)
- [Quick Start](#quick-start)
- [Core Modules](#core-modules)
  - [Profiles](#cyberfighterprofile)
  - [System Settings](#cyberfightersystem)
  - [Nix Configuration](#cyberfighternix)
  - [User Groups](#cyberfightersystemextragroups)
- [Feature Modules](#feature-modules)
  - [Packages](#cyberfighterpackages)
  - [Desktop Environment](#cyberfighterfeaturesdesktop)
  - [Graphics](#cyberfighterfeaturesgraphics)
  - [Sound](#cyberfighterfeaturessound)
  - [Fonts](#cyberfighterfeaturesfonts)
  - [Bluetooth](#cyberfighterfeaturesbluetooth)
  - [Gaming](#cyberfighterfeaturesgaming)
  - [Docker](#cyberfighterfeaturesdocker)
  - [Flatpak](#cyberfighterfeaturesflatpak)
  - [Filesystems](#cyberfighterfilesystems)
  - [Networking](#cyberfighterfeaturesnetworking)
  - [Printing](#cyberfighterfeaturesprinting)
  - [SSH](#cyberfighterfeaturesssh)
  - [Tailscale](#cyberfighterfeaturestailscale)
  - [VPN](#cyberfighterfeaturesvpn)
  - [VSCode](#cyberfighterfeaturesvscode)
  - [Security](#cyberfighterfeaturessecurity)
  - [SOPS Secrets](#cyberfighterfeaturessops)
- [Profile Reference](#profile-reference)
- [Example Configurations](#example-configurations)

## Host Registration System

This repository uses a centralized host registration pattern that keeps configurations DRY and consistent.

### The Three-File Pattern

Every host is defined across three files:

1. **hosts/default.nix** - Host metadata registry
2. **flake.nix** - Host configuration builder
3. **hosts/<hostname>/configuration.nix** - Host-specific features

### File 1: hosts/default.nix

This is the **single source of truth** for host metadata. Always start here when adding a new host.

```nix
{
  my-new-host = {
    profile = "desktop";  # or "wsl", "minimal"
    system = {
      hostname = "my-new-host";
      username = "myuser";
      userDescription = "My Full Name";
    };
  };
}
```

**What gets set here**:
- Profile (desktop/wsl/minimal)
- Hostname
- Username
- User description

### File 2: flake.nix

Add your host to the configuration builders. The flake imports `hosts/default.nix` and uses helper functions.

```nix
# Import at the top (already done)
hostConfigs = import ./hosts/default.nix;

# Add to nixosConfigurations:
nixosConfigurations = {
  # ... existing hosts ...
  my-new-host = mkNixosSystem "my-new-host" hostConfigs.my-new-host;
};

# Add to homeConfigurations:
homeConfigurations = {
  # ... existing configs ...
  "myuser@my-new-host" = mkHomeConfig "my-new-host" hostConfigs.my-new-host;
};
```

**Helper functions**:
- `mkNixosSystem` - Creates NixOS configuration with metadata
- `mkHomeConfig` - Creates home-manager configuration with metadata

### File 3: hosts/<hostname>/configuration.nix

This file only contains **feature configuration**. Profile, hostname, and username are inherited.

```nix
{
  imports = [ ../../modules ];
  
  # These are automatically set from hosts/default.nix:
  # - cyberfighter.profile.enable
  # - cyberfighter.system.hostname
  # - cyberfighter.system.username
  # - cyberfighter.system.userDescription
  
  # Only configure features and overrides:
  cyberfighter.features = {
    desktop.environment = "plasma6";
    graphics.enable = true;
    docker.enable = true;
  };
}
```

### Why This Pattern?

**Benefits**:
1. **DRY** - Define hostname/username once
2. **Consistent** - All hosts follow same structure
3. **Simple** - Host configs focus on features only
4. **Type-safe** - Metadata validated and passed to modules
5. **Scalable** - Easy to add many hosts

**Before** (old pattern):
```nix
# Had to repeat in every host config:
cyberfighter.system = {
  hostname = "my-host";
  username = "myuser";
  userDescription = "My Full Name";
};
cyberfighter.profile.enable = "desktop";
```

**After** (current pattern):
```nix
# Just configure features:
cyberfighter.features.desktop.environment = "plasma6";
```

### Example: Adding a New Host

Complete walkthrough:

**Step 1: Edit hosts/default.nix**
```nix
{
  # ... existing hosts ...
  
  laptop = {
    profile = "desktop";
    system = {
      hostname = "laptop";
      username = "john";
      userDescription = "John Doe";
    };
  };
}
```

**Step 2: Edit flake.nix**
```nix
nixosConfigurations = {
  # ... existing ...
  laptop = mkNixosSystem "laptop" hostConfigs.laptop;
};

homeConfigurations = {
  # ... existing ...
  "john@laptop" = mkHomeConfig "laptop" hostConfigs.laptop;
};
```

**Step 3: Create hosts/laptop/configuration.nix**
```nix
{
  imports = [ ../../modules ];
  
  cyberfighter.features = {
    desktop.environment = "plasma6";
    graphics = {
      enable = true;
      nvidia = {
        enable = true;
        prime = {
          enable = true;
          intelBusId = "PCI:0:2:0";
          nvidiaBusId = "PCI:1:0:0";
        };
      };
    };
    bluetooth.enable = true;
  };
}
```

**Step 4: Build**
```bash
sudo nixos-rebuild switch --flake .#laptop
```

## Quick Start

### Host Registration System

This repository uses a centralized host registration system. Before creating host-specific configurations:

**1. Register your host in hosts/default.nix:**
```nix
{
  # ... existing hosts ...
  
  my-nixos = {
    profile = "desktop";  # or "wsl", "minimal"
    system = {
      hostname = "my-nixos";
      username = "myuser";
      userDescription = "My Full Name";
    };
  };
}
```

**2. Add to flake.nix:**
```nix
# In nixosConfigurations:
my-nixos = mkNixosSystem "my-nixos" hostConfigs.my-nixos;

# In homeConfigurations:
"myuser@my-nixos" = mkHomeConfig "my-nixos" hostConfigs.my-nixos;
```

**3. Create host configuration (hosts/my-nixos/configuration.nix):**

### Minimal Configuration

```nix
{
  imports = [ ../../modules ];
  
  # Profile, hostname, username already set via hosts/default.nix
  # Just configure features:
  cyberfighter.features = {
    desktop.environment = "plasma6";
  };
}
```

### Custom Configuration

```nix
{
  imports = [ ../../modules ];
  
  # Override profile if needed (usually not necessary)
  # cyberfighter.profile.enable = lib.mkForce "none";
  
  # Configure features and packages
  cyberfighter = {
    packages.extraPackages = with pkgs; [
      htop
      neofetch
    ];
    
    features = {
      desktop.environment = "plasma6";
      graphics.enable = true;
      sound.enable = true;
      docker.enable = true;
    };
  };
}
```

**Note**: The profile, hostname, and username are automatically inherited from `hosts/default.nix`. You only need to configure additional features in your host-specific configuration.

## Core Modules

### `cyberfighter.profile`

Predefined system profiles that bundle common settings.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | `"desktop"` \| `"wsl"` \| `"minimal"` \| `"none"` | `"none"` | System profile to use |

#### Examples

```nix
# Desktop workstation
cyberfighter.profile.enable = "desktop";
```

```nix
# WSL development environment
cyberfighter.profile.enable = "wsl";
```

```nix
# Minimal server
cyberfighter.profile.enable = "minimal";
```

```nix
# No profile - manual configuration
cyberfighter.profile.enable = "none";
```

#### What Each Profile Enables

See [Profile Reference](#profile-reference) section for complete details.

---

### `cyberfighter.system`

Core system configuration including hostname, user, timezone, and bootloader.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `username` | string | `"cyberfighter"` | Primary system username |
| `userDescription` | string | `"Jonathan Guillot"` | Full name/description of user |
| `hostname` | string | **required** | System hostname |
| `timeZone` | string | `"America/Los_Angeles"` | System timezone |
| `locale` | string | `"en_US.UTF-8"` | System locale |
| `stateVersion` | string | `"25.05"` | NixOS state version |
| `bootloader.systemd-boot` | bool | `false` | Enable systemd-boot bootloader |
| `bootloader.efiCanTouchVariables` | bool | `true` | Allow EFI variable modification |
| `bootloader.luksDevice` | null \| string | `null` | LUKS device UUID for encrypted root |
| `extraGroups` | list of string | `[]` | Additional groups for user |

#### Examples

```nix
# Basic system configuration
cyberfighter.system = {
  hostname = "workstation";
  username = "john";
  userDescription = "John Doe";
};
```

```nix
# Full system configuration with bootloader
cyberfighter.system = {
  hostname = "laptop";
  username = "jane";
  userDescription = "Jane Smith";
  timeZone = "Europe/London";
  locale = "en_GB.UTF-8";
  stateVersion = "24.11";
  
  bootloader = {
    systemd-boot = true;
    efiCanTouchVariables = true;
  };
  
  extraGroups = [ "docker" "libvirtd" ];
};
```

```nix
# System with encrypted root
cyberfighter.system = {
  hostname = "secure-laptop";
  username = "user";
  
  bootloader = {
    systemd-boot = true;
    luksDevice = "12345678-1234-1234-1234-123456789abc";
  };
};
```

```nix
# WSL system (no bootloader)
cyberfighter.system = {
  hostname = "dev-wsl";
  username = "developer";
  bootloader.systemd-boot = false;
};
```

#### Notes

- User automatically gets `wheel` and `networkmanager` groups (if NetworkManager enabled)
- Default shell is zsh for all users
- To find LUKS UUID: `sudo cryptsetup luksUUID /dev/sdXY`
- Valid timezone values: `timedatectl list-timezones`

---

### `cyberfighter.nix`

Nix daemon and build system configuration.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enableDevenv` | bool | `true` | Enable devenv.sh cachix substituter |
| `trustedUsers` | list of string | `[ "root" ]` | Trusted users for Nix daemon |
| `keepOutputs` | bool | `true` | Keep build outputs in store |
| `keepDerivations` | bool | `true` | Keep derivations in store |
| `extraOptions` | string | `""` | Additional nix.conf options |

#### Examples

```nix
# Standard development setup
cyberfighter.nix = {
  enableDevenv = true;
  trustedUsers = [ "root" "myuser" ];
};
```

```nix
# Server setup without devenv
cyberfighter.nix = {
  enableDevenv = false;
  trustedUsers = [ "root" "admin" ];
  keepOutputs = false;
  keepDerivations = false;
};
```

```nix
# Custom Nix configuration
cyberfighter.nix = {
  trustedUsers = [ "root" "builder" "developer" ];
  extraOptions = ''
    max-jobs = auto
    cores = 0
    sandbox = true
  '';
};
```

#### Notes

- Trusted users can use `--option` flags and import unsigned paths
- `keepOutputs` and `keepDerivations` help with garbage collection
- Automatic configuration includes flakes and nix-command features

---

## Feature Modules

### `cyberfighter.packages`

System package management with predefined package sets.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `includeBase` | bool | `true` | Include base system packages |
| `includeDev` | bool | `false` | Include development packages |
| `includeDesktop` | bool | `false` | Include desktop packages |
| `extraPackages` | list of package | `[]` | Additional custom packages |

#### Package Sets

**Base Packages** (`includeBase = true`):
```nix
[
  htop btop vim wget cifs-utils lshw pciutils
  git gh lazyjj bitwarden-cli appimage-run
  xclip opencode age sops grc distrobox
]
```

**Development Packages** (`includeDev = true`):
```nix
[
  nodejs nil esphome platformio
]
```

**Desktop Packages** (`includeDesktop = true`):
```nix
[
  kitty wofi wineWowPackages.stable bitwarden-desktop
]
```

#### Examples

```nix
# Minimal system - base packages only
cyberfighter.packages = {
  includeBase = true;
};
```

```nix
# Development workstation
cyberfighter.packages = {
  includeBase = true;
  includeDev = true;
  includeDesktop = true;
  extraPackages = with pkgs; [
    neofetch
    tree
  ];
};
```

```nix
# Server - custom packages only
cyberfighter.packages = {
  includeBase = false;
  extraPackages = with pkgs; [
    git
    vim
    htop
    docker-compose
  ];
};
```

```nix
# Gaming setup - add game launchers
cyberfighter.packages = {
  includeBase = true;
  includeDesktop = true;
  extraPackages = with pkgs; [
    lutris
    heroic
    bottles
  ];
};
```

---

### `cyberfighter.features.desktop`

Desktop environment configuration supporting multiple DEs and display managers.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable desktop environment support |
| `environment` | `"plasma6"` \| `"plasma5"` \| `"gnome"` \| `"hyprland"` \| `"none"` | `"plasma6"` | Desktop environment to use |
| `displayManager` | `"sddm"` \| `"gdm"` \| `"none"` | `"sddm"` | Display manager to use |
| `firefox` | bool | `false` | Install Firefox browser |

#### Default Packages

- `kitty` - Terminal emulator
- `wofi` - Application launcher
- `kdePackages.kate` - Text editor (Plasma6 only)

#### Examples

```nix
# Plasma 6 desktop
cyberfighter.features.desktop = {
  enable = true;
  environment = "plasma6";
  displayManager = "sddm";
  firefox = true;
};
```

```nix
# GNOME desktop
cyberfighter.features.desktop = {
  enable = true;
  environment = "gnome";
  displayManager = "gdm";
  firefox = true;
};
```

```nix
# Hyprland (Wayland compositor)
cyberfighter.features.desktop = {
  enable = true;
  environment = "hyprland";
  displayManager = "sddm";
};
```

```nix
# Plasma 5 (older KDE version)
cyberfighter.features.desktop = {
  enable = true;
  environment = "plasma5";
  displayManager = "sddm";
};
```

```nix
# Desktop support without specific DE (custom setup)
cyberfighter.features.desktop = {
  enable = true;
  environment = "none";
  displayManager = "none";
  # Use with window managers like i3, awesome, etc.
};
```

#### Notes

- SDDM is recommended for KDE Plasma
- GDM is recommended for GNOME
- Hyprland requires Wayland support
- `firefox` option installs system-wide Firefox (can also use home-manager)

---

### `cyberfighter.features.graphics`

GPU drivers and graphics acceleration configuration.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable graphics acceleration |
| `nvidia.enable` | bool | `false` | Enable Nvidia drivers |
| `nvidia.powerManagement` | bool | `false` | Enable Nvidia power management |
| `nvidia.openDriver` | bool | `true` | Use open-source Nvidia driver |
| `nvidia.prime.enable` | bool | `false` | Enable Nvidia Prime (hybrid graphics) |
| `nvidia.prime.intelBusId` | string | `""` | Intel GPU bus ID |
| `nvidia.prime.nvidiaBusId` | string | `""` | Nvidia GPU bus ID |
| `amd.enable` | bool | `false` | Enable AMD drivers |

#### Default Packages

When `enable = true`:
```nix
[ vulkan-tools vulkan-loader virtualgl ]
```

When `amd.enable = true` (additional):
```nix
[ clinfo amdgpu_top rocmPackages.clr.icd ]
```

#### Examples

```nix
# Nvidia GPU only
cyberfighter.features.graphics = {
  enable = true;
  nvidia.enable = true;
};
```

```nix
# Nvidia with proprietary driver
cyberfighter.features.graphics = {
  enable = true;
  nvidia = {
    enable = true;
    openDriver = false;  # Use proprietary driver
    powerManagement = true;
  };
};
```

```nix
# Nvidia Prime (laptop with Intel iGPU + Nvidia dGPU)
cyberfighter.features.graphics = {
  enable = true;
  nvidia = {
    enable = true;
    prime = {
      enable = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };
};
```

```nix
# AMD GPU
cyberfighter.features.graphics = {
  enable = true;
  amd.enable = true;
};
```

```nix
# Intel only (integrated graphics)
cyberfighter.features.graphics = {
  enable = true;
  # No nvidia or amd - uses Intel drivers automatically
};
```

#### Finding Bus IDs

To find GPU bus IDs for Prime configuration:

```bash
# Show all GPUs
lspci | grep -E "VGA|3D"

# Output example:
# 00:02.0 VGA compatible controller: Intel Corporation
# 01:00.0 3D controller: NVIDIA Corporation

# Bus ID format: PCI:X:Y:Z
# For 00:02.0 -> PCI:0:2:0
# For 01:00.0 -> PCI:1:0:0
```

#### Notes

- Prime sync mode is used by default (better compatibility)
- Open-source Nvidia driver (`openDriver = true`) works with newer GPUs (Turing+)
- AMD drivers are enabled by default when `amd.enable = true`
- Wayland support is enabled for Nvidia

---

### `cyberfighter.features.sound`

Audio configuration with PipeWire.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable sound support |

#### Examples

```nix
# Enable sound
cyberfighter.features.sound.enable = true;
```

#### What's Configured

When enabled:
- Disables PulseAudio
- Enables PipeWire
- Enables PipeWire ALSA support
- Enables PipeWire ALSA 32-bit support (for games)
- Enables PulseAudio compatibility layer

#### Notes

- PipeWire is the modern Linux audio server
- Includes PulseAudio compatibility for older apps
- ALSA 32-bit support enables audio in 32-bit applications and games
- No additional configuration needed for most use cases

---

### `cyberfighter.features.fonts`

Programming font packages.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Install programming fonts |

#### Installed Fonts

When enabled:
```nix
[
  fira-code
  fira-mono
  (nerdfonts.override { fonts = [ "FiraCode" "FiraMono" ]; })
]
```

#### Examples

```nix
# Install fonts
cyberfighter.features.fonts.enable = true;
```

#### Notes

- Fira Code includes programming ligatures
- Nerd Fonts include icon glyphs for terminal prompts
- These fonts work well with terminals and code editors

---

### `cyberfighter.features.bluetooth`

Bluetooth support and management.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable Bluetooth support |
| `powerOnBoot` | bool | `true` | Power on Bluetooth controller at boot |
| `extraPackages` | list of package | `[]` | Additional Bluetooth packages |

#### Default Packages

When enabled:
```nix
[ bluez bluez-tools ]
```

#### Examples

```nix
# Basic Bluetooth
cyberfighter.features.bluetooth.enable = true;
```

```nix
# Bluetooth with manual power on
cyberfighter.features.bluetooth = {
  enable = true;
  powerOnBoot = false;  # Don't power on at boot
};
```

```nix
# Bluetooth with additional tools
cyberfighter.features.bluetooth = {
  enable = true;
  extraPackages = with pkgs; [
    bluez-alsa
    bluez-tools
  ];
};
```

#### Notes

- Blueman (GUI manager) is automatically installed on desktop systems
- `powerOnBoot = true` means Bluetooth is ready immediately after boot
- Most laptops and desktops work out of the box

---

### `cyberfighter.features.gaming`

Gaming support with Steam and performance tools.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable gaming support |
| `steam.enable` | bool | `true` | Enable Steam (when gaming enabled) |
| `steam.remotePlay` | bool | `true` | Enable Steam Remote Play |
| `steam.localNetworkGameTransfers` | bool | `true` | Enable local network game transfers |
| `steam.gamescopeSession` | bool | `true` | Enable gamescope session |
| `gamemode` | bool | `true` | Enable Feral GameMode |
| `mangohud` | bool | `true` | Enable MangoHud overlay |
| `protonup` | bool | `true` | Enable ProtonUp-Qt |
| `extraPackages` | list of package | `[]` | Additional gaming packages |

#### Examples

```nix
# Full gaming setup
cyberfighter.features.gaming = {
  enable = true;
};
```

```nix
# Gaming with additional launchers
cyberfighter.features.gaming = {
  enable = true;
  extraPackages = with pkgs; [
    lutris      # Multi-platform game launcher
    heroic      # Epic Games and GOG launcher
    bottles     # Windows app compatibility
  ];
};
```

```nix
# Steam only, no extras
cyberfighter.features.gaming = {
  enable = true;
  gamemode = false;
  mangohud = false;
  protonup = false;
};
```

```nix
# Steam with specific settings
cyberfighter.features.gaming = {
  enable = true;
  steam = {
    enable = true;
    remotePlay = false;
    localNetworkGameTransfers = false;
    gamescopeSession = false;
  };
};
```

#### What Each Feature Does

- **Steam**: Valve's game distribution platform
- **GameMode**: Optimizes system performance for games
- **MangoHud**: FPS and performance overlay (Ctrl+F12 to toggle)
- **ProtonUp-Qt**: Manage Proton versions for Steam Play
- **Gamescope**: Micro-compositor for games (better performance)

#### Notes

- GameMode automatically activates when supported games start
- MangoHud works with both native and Proton games
- Steam Play (Proton) enables Windows games on Linux
- ProtonUp-Qt lets you install GE-Proton and other custom builds

---

### `cyberfighter.features.docker`

Docker container runtime.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable Docker |
| `rootless` | bool | `false` | Enable rootless mode |
| `enableOnBoot` | bool | `true` | Start Docker on boot |

#### Examples

```nix
# Standard Docker
cyberfighter.features.docker.enable = true;
```

```nix
# Rootless Docker (more secure)
cyberfighter.features.docker = {
  enable = true;
  rootless = true;
};
```

```nix
# Docker without auto-start
cyberfighter.features.docker = {
  enable = true;
  enableOnBoot = false;
};
```

#### Notes

- User must be in `docker` group (add to `system.extraGroups`)
- Rootless mode doesn't require root privileges
- Rootless mode has some limitations (networking, privileged containers)
- Enable on boot is recommended for server environments

---

### `cyberfighter.features.flatpak`

Flatpak application bundles.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable Flatpak and Flathub |
| `browsers` | bool | `false` | Install browser bundle |
| `cad` | bool | `false` | Install CAD software bundle |
| `electronics` | bool | `false` | Install electronics bundle |
| `extraPackages` | list of string | `[]` | Additional Flatpak app IDs |

#### Package Bundles

**Browsers** (`browsers = true`):
- `io.github.zen_browser.zen` - Zen Browser
- `org.chromium.Chromium` - Chromium

**CAD** (`cad = true`):
- `org.openscad.OpenSCAD` - OpenSCAD
- `org.freecadweb.FreeCAD` - FreeCAD

**Electronics** (`electronics = true`):
- `cc.arduino.arduinoide` - Arduino IDE
- `org.fritzing.Fritzing` - Fritzing

#### Examples

```nix
# Basic Flatpak
cyberfighter.features.flatpak.enable = true;
```

```nix
# With predefined bundles
cyberfighter.features.flatpak = {
  enable = true;
  browsers = true;
  cad = true;
};
```

```nix
# With custom apps
cyberfighter.features.flatpak = {
  enable = true;
  extraPackages = [
    "com.spotify.Client"
    "us.zoom.Zoom"
    "com.slack.Slack"
    "com.discordapp.Discord"
    "com.obsproject.Studio"
  ];
};
```

```nix
# Full setup
cyberfighter.features.flatpak = {
  enable = true;
  browsers = true;
  cad = true;
  electronics = true;
  extraPackages = [
    "com.moonlight_stream.Moonlight"
    "org.gimp.GIMP"
    "org.inkscape.Inkscape"
  ];
};
```

#### Finding Flatpak Apps

Search for apps:
```bash
flatpak search <appname>

# Example
flatpak search spotify
# com.spotify.Client
```

Browse at: https://flathub.org/

#### Notes

- Flathub remote is automatically added
- Apps are sandboxed for security
- Use Flatseal (GUI) to manage app permissions

---

### `cyberfighter.filesystems`

Network filesystem mounts, primarily TrueNAS CIFS shares.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `truenas.enable` | bool | `false` | Enable TrueNAS mounts |
| `truenas.server` | string | `"truenas.cyberfighter.space"` | TrueNAS server hostname |
| `truenas.mounts.<name>.share` | string | required | Share path on server |
| `truenas.mounts.<name>.mountPoint` | string | required | Local mount point |
| `smbCredentials` | string | `"/etc/nixos/smb-secrets"` | SMB credentials file path |
| `extraMounts` | attrs | `{}` | Additional filesystem definitions |

#### SMB Credentials File Format

File: `/etc/nixos/smb-secrets` (or your custom path)
```
username=myuser
password=mypassword
domain=WORKGROUP
```

**Important**: Protect this file:
```bash
sudo chmod 600 /etc/nixos/smb-secrets
```

Or use SOPS for encrypted credentials (recommended).

#### Examples

```nix
# Single TrueNAS mount
cyberfighter.filesystems.truenas = {
  enable = true;
  mounts = {
    home = {
      share = "userdata/myuser";
      mountPoint = "/mnt/nas-home";
    };
  };
};
```

```nix
# Multiple TrueNAS mounts
cyberfighter.filesystems.truenas = {
  enable = true;
  server = "nas.local";
  mounts = {
    home = {
      share = "userdata/myuser";
      mountPoint = "/mnt/nas-home";
    };
    media = {
      share = "media";
      mountPoint = "/mnt/nas-media";
    };
    backups = {
      share = "backups/myuser";
      mountPoint = "/mnt/nas-backups";
    };
  };
};
```

```nix
# Custom credentials file
cyberfighter.filesystems = {
  smbCredentials = "/run/secrets/smb-secrets";  # SOPS managed
  truenas = {
    enable = true;
    mounts = {
      home = {
        share = "userdata/myuser";
        mountPoint = "/mnt/nas";
      };
    };
  };
};
```

```nix
# Additional filesystem mounts
cyberfighter.filesystems = {
  truenas = {
    enable = true;
    mounts = {
      home = {
        share = "userdata/myuser";
        mountPoint = "/mnt/nas";
      };
    };
  };
  
  extraMounts = {
    "/mnt/external" = {
      device = "/dev/disk/by-uuid/XXXX-XXXX";
      fsType = "ext4";
      options = [ "defaults" ];
    };
  };
};
```

#### Notes

- Mounts are automatically created at boot
- Mount points are created if they don't exist
- CIFS utilities are automatically installed
- Consider using SOPS for credential management

---

### `cyberfighter.features.networking`

Network management configuration.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `networkmanager` | bool | `true` | Enable NetworkManager |

#### Examples

```nix
# Enable NetworkManager (default)
cyberfighter.features.networking.networkmanager = true;
```

```nix
# Disable NetworkManager (for servers)
cyberfighter.features.networking.networkmanager = false;
```

#### Notes

- NetworkManager is recommended for desktops and laptops
- Server setups may prefer static network configuration
- User is automatically added to `networkmanager` group if enabled
- `nmcli` and `nmtui` commands available when enabled

---

### `cyberfighter.features.printing`

CUPS printing support.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable CUPS printing |

#### Examples

```nix
# Enable printing
cyberfighter.features.printing.enable = true;
```

#### Notes

- Enables CUPS (Common Unix Printing System)
- Automatically discovers network printers
- Access web interface at: http://localhost:631
- Many printers work automatically via driverless printing

---

### `cyberfighter.features.ssh`

OpenSSH server configuration.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable SSH server |
| `ports` | list of int | `[22]` | SSH ports to listen on |
| `passwordAuth` | bool | `true` | Allow password authentication |
| `permitRootLogin` | string | `"prohibit-password"` | Root login policy |

#### Examples

```nix
# Basic SSH server
cyberfighter.features.ssh.enable = true;
```

```nix
# Secure SSH configuration
cyberfighter.features.ssh = {
  enable = true;
  passwordAuth = false;  # Key-only authentication
  permitRootLogin = "no";
};
```

```nix
# SSH on custom port
cyberfighter.features.ssh = {
  enable = true;
  ports = [ 2222 ];
  passwordAuth = false;
};
```

```nix
# SSH on multiple ports
cyberfighter.features.ssh = {
  enable = true;
  ports = [ 22 2222 ];
};
```

#### `permitRootLogin` Options

- `"yes"` - Root can login with password
- `"no"` - Root cannot login at all
- `"prohibit-password"` - Root can login with key only (recommended)
- `"forced-commands-only"` - Root can only run specific commands

#### Notes

- Key-only authentication (`passwordAuth = false`) is more secure
- Always use SSH keys for production servers
- Consider fail2ban for additional security
- Open firewall port if needed: `networking.firewall.allowedTCPPorts = [ 22 ];`

---

### `cyberfighter.features.tailscale`

Tailscale VPN mesh network.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable Tailscale |
| `useRoutingFeatures` | string | `"client"` | Routing mode: `"client"`, `"server"`, or `"both"` |
| `acceptRoutes` | bool | `true` | Accept routes from other nodes |
| `extraUpFlags` | list of string | `[]` | Additional `tailscale up` flags |

#### Examples

```nix
# Basic Tailscale client
cyberfighter.features.tailscale.enable = true;
```

```nix
# Tailscale with SSH enabled
cyberfighter.features.tailscale = {
  enable = true;
  extraUpFlags = [ "--ssh" ];
};
```

```nix
# Tailscale exit node
cyberfighter.features.tailscale = {
  enable = true;
  useRoutingFeatures = "server";
  extraUpFlags = [ "--advertise-exit-node" ];
};
```

```nix
# Tailscale subnet router
cyberfighter.features.tailscale = {
  enable = true;
  useRoutingFeatures = "server";
  extraUpFlags = [ "--advertise-routes=192.168.1.0/24" ];
};
```

```nix
# Full Tailscale setup
cyberfighter.features.tailscale = {
  enable = true;
  useRoutingFeatures = "both";
  acceptRoutes = true;
  extraUpFlags = [
    "--ssh"
    "--accept-dns=false"
  ];
};
```

#### Common Extra Flags

- `--ssh` - Enable Tailscale SSH
- `--accept-dns=false` - Don't use Tailscale DNS
- `--advertise-exit-node` - Advertise as exit node
- `--advertise-routes=CIDR` - Advertise subnet routes
- `--accept-routes` - Accept subnet routes (also available as option)

#### Notes

- Run `tailscale up` after first install to authenticate
- View status: `tailscale status`
- Tailscale provides zero-config VPN mesh networking
- Exit nodes let you route all traffic through another machine

---

### `cyberfighter.features.vpn`

VPN client configurations.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `pia.enable` | bool | `false` | Enable Private Internet Access VPN |
| `pia.autoStart` | bool | `false` | Automatically connect on boot |
| `pia.server` | string | `"us-newjersey.privacy.network"` | PIA server hostname |
| `pia.port` | int | `1198` | PIA server port |
| `pia.credentialsFile` | string | `"/run/secrets/pia-credentials"` | Path to credentials file |

#### PIA Credentials File Format

File managed by SOPS at `/run/secrets/pia-credentials`:
```
username
password
```

#### Examples

```nix
# Basic PIA VPN (manual start)
cyberfighter.features.vpn.pia.enable = true;
```

```nix
# PIA VPN with auto-connect
cyberfighter.features.vpn.pia = {
  enable = true;
  autoStart = true;
};
```

```nix
# PIA VPN with custom server
cyberfighter.features.vpn.pia = {
  enable = true;
  server = "us-california.privacy.network";
  port = 1198;
};
```

#### Available PIA Servers

- US: `us-newjersey.privacy.network`, `us-california.privacy.network`, etc.
- EU: `uk-london.privacy.network`, `de-frankfurt.privacy.network`, etc.
- See PIA documentation for full server list

#### VPN Control

```bash
# Start VPN
sudo systemctl start openvpn-pia

# Stop VPN
sudo systemctl stop openvpn-pia

# Status
sudo systemctl status openvpn-pia

# View logs
sudo journalctl -u openvpn-pia
```

#### Notes

- Requires SOPS secrets configuration
- See [SOPS-MIGRATION.md](SOPS-MIGRATION.md) for setup
- VPN credentials must be in SOPS secrets.yaml
- OpenVPN is used as the underlying technology

---

### `cyberfighter.features.vscode`

Visual Studio Code installation.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Install VSCode system-wide |

#### Examples

```nix
# Install VSCode
cyberfighter.features.vscode.enable = true;
```

#### Notes

- Installs VSCode system-wide
- Consider using home-manager for user-specific VSCode config
- Enable unfree packages: `nixpkgs.config.allowUnfree = true;`
- Extensions can be managed via home-manager or VSCode settings sync

---

### `cyberfighter.features.security`

Security tools and application sandboxing.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `firejail` | bool | `false` | Enable Firejail sandboxing |

#### Examples

```nix
# Enable Firejail
cyberfighter.features.security.firejail = true;
```

#### Using Firejail

```bash
# Run application in sandbox
firejail firefox

# Run with specific profile
firejail --profile=/etc/firejail/firefox.profile firefox

# List running sandboxes
firejail --list

# View available profiles
ls /etc/firejail/*.profile
```

#### Notes

- Firejail creates security sandboxes for applications
- Reduces attack surface by limiting application access
- Profiles available for many common applications
- Some applications may not work correctly when sandboxed

---

### `cyberfighter.features.sops`

SOPS (Secrets OPerationS) secrets management.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable SOPS secrets |
| `defaultSopsFile` | path | required | Path to secrets.yaml |
| `sshKeyPath` | string | `"/etc/ssh/ssh_host_ed25519_key"` | SSH key for decryption |

#### Examples

```nix
# Enable SOPS with default settings
cyberfighter.features.sops = {
  enable = true;
  defaultSopsFile = ../../secrets/secrets.yaml;
};
```

```nix
# Custom SSH key path
cyberfighter.features.sops = {
  enable = true;
  defaultSopsFile = ../../secrets/secrets.yaml;
  sshKeyPath = "/etc/ssh/custom_host_key";
};
```

#### Using Secrets in Configuration

```nix
# Define a secret
config.sops.secrets."my-secret" = {
  # Secret will be available at /run/secrets/my-secret
};

# Use secret in a service
services.myservice = {
  enable = true;
  passwordFile = config.sops.secrets."my-secret".path;
};

# Multiple secrets
config.sops.secrets = {
  "api-key" = { };
  "database-password" = { };
  "smtp-credentials" = { };
};
```

#### Managing Secrets

```bash
# Edit secrets (first time setup required)
sops secrets/secrets.yaml

# Add new host key to .sops.yaml first
# Then edit secrets
```

#### Complete Documentation

See **[SOPS-MIGRATION.md](SOPS-MIGRATION.md)** for:
- Initial setup
- Adding new secrets
- Adding new hosts
- Troubleshooting

---

## Profile Reference

### Desktop Profile

**Enabled when**: `cyberfighter.profile.enable = "desktop"`

**What it configures**:

```nix
{
  features = {
    desktop = {
      enable = true;
      environment = "plasma6";
    };
    graphics.enable = true;
    sound.enable = true;
    networking.networkmanager = true;
  };
  
  packages = {
    includeBase = true;
    includeDesktop = true;
  };
  
  system.bootloader.systemd-boot = true;
  
  # Optional (disabled by default):
  # features.printing.enable = false;
}
```

**Use case**: Full desktop workstation or laptop

---

### WSL Profile

**Enabled when**: `cyberfighter.profile.enable = "wsl"`

**What it configures**:

```nix
{
  features = {
    graphics.enable = true;  # For GUI apps via WSLg
    networking.networkmanager = false;
  };
  
  packages.includeBase = true;
  
  system.bootloader.systemd-boot = false;
}
```

**Use case**: Windows Subsystem for Linux environments

---

### Minimal Profile

**Enabled when**: `cyberfighter.profile.enable = "minimal"`

**What it configures**:

```nix
{
  features.networking.networkmanager = true;
  
  packages.includeBase = true;
  
  system.bootloader.systemd-boot = true;
}
```

**Use case**: Minimal server or development environment

---

## Example Configurations

### Example 1: Desktop Workstation

```nix
{
  imports = [ ../../modules ];
  
  cyberfighter = {
    profile.enable = "desktop";
    
    system = {
      hostname = "workstation";
      username = "john";
      extraGroups = [ "docker" ];
    };
    
    nix.trustedUsers = [ "root" "john" ];
    
    packages.extraPackages = with pkgs; [
      vscode
      gimp
    ];
    
    features = {
      desktop = {
        environment = "plasma6";
        firefox = true;
      };
      
      docker.enable = true;
      
      flatpak = {
        enable = true;
        browsers = true;
        extraPackages = [
          "com.slack.Slack"
          "us.zoom.Zoom"
        ];
      };
    };
  };
}
```

### Example 2: Gaming PC

```nix
{
  imports = [ ../../modules ];
  
  cyberfighter = {
    profile.enable = "desktop";
    
    system = {
      hostname = "gaming-rig";
      username = "gamer";
    };
    
    features = {
      desktop.environment = "plasma6";
      
      graphics = {
        enable = true;
        nvidia = {
          enable = true;
          powerManagement = true;
        };
      };
      
      gaming = {
        enable = true;
        extraPackages = with pkgs; [ lutris heroic ];
      };
      
      sound.enable = true;
    };
  };
}
```

### Example 3: Development Server

```nix
{
  imports = [ ../../modules ];
  
  cyberfighter = {
    profile.enable = "minimal";
    
    system = {
      hostname = "dev-server";
      username = "admin";
      extraGroups = [ "docker" ];
    };
    
    packages.includeDev = true;
    
    features = {
      ssh = {
        enable = true;
        passwordAuth = false;
        permitRootLogin = "no";
      };
      
      docker.enable = true;
      
      tailscale = {
        enable = true;
        extraUpFlags = [ "--ssh" ];
      };
    };
  };
}
```

### Example 4: Laptop with Hybrid Graphics

```nix
{
  imports = [ ../../modules ];
  
  cyberfighter = {
    profile.enable = "desktop";
    
    system = {
      hostname = "laptop";
      username = "user";
    };
    
    features = {
      desktop = {
        environment = "gnome";
        firefox = true;
      };
      
      graphics = {
        enable = true;
        nvidia = {
          enable = true;
          prime = {
            enable = true;
            intelBusId = "PCI:0:2:0";
            nvidiaBusId = "PCI:1:0:0";
          };
          powerManagement = true;
        };
      };
      
      bluetooth.enable = true;
      printing.enable = true;
    };
  };
}
```

### Example 5: WSL Development Environment

```nix
{
  imports = [ ../../modules ];
  
  cyberfighter = {
    profile.enable = "wsl";
    
    system = {
      hostname = "work-wsl";
      username = "developer";
      extraGroups = [ "docker" ];
    };
    
    packages = {
      includeDev = true;
      extraPackages = with pkgs; [
        awscli2
        kubectl
        terraform
      ];
    };
    
    features = {
      docker.enable = true;
      
      vscode.enable = true;
      
      tailscale.enable = true;
    };
  };
}
```

### Example 6: Home Lab Server with NAS

```nix
{
  imports = [ ../../modules ];
  
  cyberfighter = {
    profile.enable = "minimal";
    
    system = {
      hostname = "homelab";
      username = "admin";
      extraGroups = [ "docker" ];
    };
    
    features = {
      ssh = {
        enable = true;
        passwordAuth = false;
      };
      
      docker.enable = true;
      
      tailscale = {
        enable = true;
        useRoutingFeatures = "server";
        extraUpFlags = [
          "--advertise-routes=192.168.1.0/24"
        ];
      };
    };
    
    filesystems.truenas = {
      enable = true;
      server = "nas.local";
      mounts = {
        media = {
          share = "media";
          mountPoint = "/mnt/media";
        };
        backups = {
          share = "backups";
          mountPoint = "/mnt/backups";
        };
      };
    };
  };
}
```

---

## Additional Resources

- **[Home Manager Documentation](HOME-MANAGER.md)** - User-level configurations
- **[SOPS Secrets Guide](SOPS-MIGRATION.md)** - Managing secrets securely
- **[Main README](../README.md)** - Installation and quick start guide
- **[NixOS Manual](https://nixos.org/manual/nixos/stable/)** - Official documentation
