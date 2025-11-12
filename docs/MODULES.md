# NixOS Module System Documentation

## Overview

This dotfiles repository uses a modular configuration system under the `cyberfighter` namespace. The system provides:

1. **Profiles** - Predefined bundles of common settings (desktop, wsl, minimal)
2. **Core Modules** - Essential configuration (system, users, nix-settings)
3. **Feature Modules** - Optional features that can be enabled/disabled

## Module Structure

```
modules/
├── default.nix        # Main import file
├── core/              # Essential system configuration
│   ├── profiles/      # System profiles
│   ├── system/        # Core settings
│   ├── users/         # User management
│   └── nix-settings/  # Nix configuration
└── features/          # Optional feature modules
    ├── desktop/       # Desktop environments
    ├── gaming/        # Gaming with Steam
    ├── bluetooth/     # Bluetooth support
    ├── graphics/      # GPU drivers
    ├── sound/         # Audio
    └── ... (15 total)
```

## Quick Start

### Using Profiles

Profiles bundle common settings together. Choose one:

```nix
cyberfighter.profile.enable = "desktop";  # Full desktop system
cyberfighter.profile.enable = "wsl";      # WSL environment
cyberfighter.profile.enable = "minimal";  # Minimal system
cyberfighter.profile.enable = "none";     # No profile (manual config)
```

The `desktop` profile automatically includes:
- Desktop environment support
- Graphics acceleration
- Sound (PipeWire)
- NetworkManager
- Base and desktop packages
- Common flatpaks (Flatseal, LibreOffice, VLC)

### System Settings

Set core system configuration:

```nix
cyberfighter.system = {
  hostname = "my-nixos";
  username = "myuser";
  userDescription = "My Full Name";
  timeZone = "America/Los_Angeles";
  locale = "en_US.UTF-8";
  stateVersion = "25.05";

  bootloader = {
    systemd-boot = true;
    efiCanTouchVariables = true;
    luksDevice = "uuid-string";  # Optional: for encrypted disks
  };

  extraGroups = [ "docker" "libvirtd" ];  # Additional user groups
};
```

## Core Configuration

### Nix Settings

```nix
cyberfighter.nix = {
  enableDevenv = true;  # Enable devenv cachix
  trustedUsers = [ "root" "myuser" ];
  keepOutputs = true;
  keepDerivations = true;
  extraOptions = ''
    # Additional nix.conf options
  '';
};
```

### Packages

```nix
cyberfighter.packages = {
  includeBase = true;       # Base packages (cifs-utils, xclip, etc.)
  includeDesktop = false;   # Desktop packages (kitty, wofi, etc.)
  extraPackages = with pkgs; [
    htop
    neofetch
  ];
};
```

### User Groups

```nix
cyberfighter.system.extraGroups = [ "docker" "libvirtd" ];
```

### Filesystems

```nix
cyberfighter.filesystems = {
  truenas = {
    enable = true;
    server = "truenas.example.com";  # Default: truenas.cyberfighter.space
    mounts = {
      home = {
        share = "userdata/username";
        mountPoint = "/mnt/truenas-home";
      };
      media = {
        share = "media";
        mountPoint = "/mnt/truenas-media";
      };
    };
  };
  smbCredentials = "/etc/nixos/smb-secrets";
  extraMounts = {
    # Additional filesystem mounts
  };
};
```

## Available Features

### Desktop Environment

```nix
cyberfighter.features.desktop = {
  enable = true;
  environment = "plasma6";  # Options: plasma6, plasma5, gnome, hyprland, none
  displayManager = "sddm";  # Options: sddm, gdm, none
  
  extraPrograms = {
    firefox = true;
    hyprland = true;
  };
};
```

### Graphics

```nix
cyberfighter.features.graphics = {
  enable = true;
  
  nvidia = {
    enable = true;
    powerManagement = false;
    openDriver = true;  # Use open source driver
    
    prime = {
      enable = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:2:0:0";
    };
  };
  
  amd = {
    enable = false;
  };
};
```

### Sound

```nix
cyberfighter.features.sound.enable = true;  # PipeWire with PulseAudio compatibility
```

### Fonts

```nix
cyberfighter.features.fonts.enable = true;  # Fira Code and Fira Mono nerd fonts
```

### Docker

```nix
cyberfighter.features.docker = {
  enable = true;
  rootless = false;      # Enable rootless mode
  enableOnBoot = true;   # Start on boot
};
```

### Flatpak

```nix
cyberfighter.features.flatpak = {
  enable = true;
  desktop = true;      # LibreOffice, VLC, Flatseal
  browsers = true;     # Zen Browser, Chromium
  cad = true;          # OpenSCAD, FreeCAD
  electronics = true;  # Arduino IDE, Fritzing
  
  extraPackages = [
    "com.moonlight_stream.Moonlight"
    "us.zoom.Zoom"
  ];
};
```

### Bluetooth

```nix
cyberfighter.features.bluetooth = {
  enable = true;
  powerOnBoot = true;  # Power on controller at boot
  extraPackages = [ ];  # Additional Bluetooth tools
};
```

### Gaming

```nix
cyberfighter.features.gaming = {
  enable = true;
  
  steam = {
    enable = true;
    remotePlay = true;
    localNetworkGameTransfers = true;
    gamescopeSession = true;
  };
  
  gamemode = true;     # Feral GameMode
  mangohud = true;     # Performance overlay
  protonup = true;     # ProtonUp-Qt
  
  extraPackages = with pkgs; [ lutris heroic ];
};
```

### Tailscale

```nix
cyberfighter.features.tailscale = {
  enable = true;
  useRoutingFeatures = "client";  # or "server", "both"
  acceptRoutes = true;
  extraUpFlags = [ "--ssh" ];
};
```

### Networking

```nix
cyberfighter.features.networking.networkmanager = true;
```

### Printing

```nix
cyberfighter.features.printing.enable = true;  # CUPS
```

### SSH

```nix
cyberfighter.features.ssh = {
  enable = true;
  ports = [ 22 ];
  passwordAuth = true;
  permitRootLogin = "prohibit-password";
};
```

### VSCode

```nix
cyberfighter.features.vscode = {
  enable = true;
  enableServer = true;   # For remote development
  syncSettings = false;  # Set to true to manage settings via Nix
  
  userSettings = {
    "workbench.colorTheme" = "One Dark Pro Darker";
    "editor.fontFamily" = "FiraCode Nerd Font Mono";
  };
};
```

Note: When `syncSettings = false`, VSCode Settings Sync can be used without conflicts.

### VPN (Private Internet Access)

```nix
cyberfighter.features.vpn.pia = {
  enable = true;
  autoStart = false;
  server = "us-newjersey.privacy.network";
  port = 1198;
};
```

Requires `pia-credentials` in SOPS secrets.yaml.

### Security

```nix
cyberfighter.features.security.firejail = true;  # Application sandboxing
```

### SOPS Secrets

```nix
cyberfighter.features.sops = {
  enable = true;
  defaultSopsFile = ../../secrets/secrets.yaml;
  sshKeyPath = "/etc/ssh/ssh_host_ed25519_key";
};
```

See [docs/SOPS-MIGRATION.md](SOPS-MIGRATION.md) for secrets management guide.

## Profile Defaults

### Desktop Profile

When `cyberfighter.profile.enable = "desktop"` is set:

- Desktop environment: enabled
- Graphics: enabled
- Sound: enabled
- NetworkManager: enabled
- Bootloader: systemd-boot enabled
- Printing: disabled by default

### WSL Profile

When `cyberfighter.profile.enable = "wsl"` is set:

- Graphics: enabled (for GUI apps)
- NetworkManager: disabled
- Bootloader: disabled

### Minimal Profile

When `cyberfighter.profile.enable = "minimal"` is set:

- NetworkManager: enabled
- Bootloader: systemd-boot enabled

## Example Configurations

### Desktop Workstation

```nix
{
  cyberfighter.profile.enable = "desktop";
  
  cyberfighter.system = {
    hostname = "workstation";
    username = "myuser";
    extraGroups = [ "docker" ];
  };
  
  cyberfighter.nix = {
    trustedUsers = [ "root" "myuser" ];
  };
  
  cyberfighter.packages = {
    includeBase = true;
    includeDesktop = true;
    extraPackages = with pkgs; [ htop neofetch ];
  };
  
  cyberfighter.features = {
    desktop.environment = "plasma6";
    docker.enable = true;
    flatpak = {
      enable = true;
      desktop = true;
      browsers = true;
      extraPackages = [ "com.slack.Slack" ];
    };
  };
  
  cyberfighter.filesystems.truenas = {
    enable = true;
    mounts = {
      home = {
        share = "userdata/myuser";
        mountPoint = "/mnt/nas-home";
      };
    };
  };
}
```

### Development WSL

```nix
{
  cyberfighter.profile.enable = "wsl";
  
  cyberfighter.system = {
    hostname = "dev-wsl";
    username = "devuser";
  };
  
  cyberfighter.features = {
    docker.enable = true;
    tailscale.enable = true;
  };
}
```

## Module Files

All modules are organized under `modules/` with the following structure:

### Core Modules (`modules/core/`)

Essential system configuration that most hosts need:

- `profiles/` - Profile definitions (desktop, wsl, minimal)
- `system/` - Core system settings (hostname, user, bootloader, timezone, locale)
- `users/` - User group management
- `nix-settings/` - Nix configuration and cache settings

### Feature Modules (`modules/features/`)

Optional features that can be enabled per-host:

- `desktop/` - Desktop environment (Plasma6/5, GNOME, Hyprland)
- `graphics/` - GPU drivers (Nvidia/AMD with Prime support)
- `sound/` - Audio configuration (PipeWire)
- `fonts/` - Programming font packages
- `bluetooth/` - Bluetooth support with Blueman
- `gaming/` - Gaming (Steam, GameMode, MangoHud, ProtonUp)
- `networking/` - NetworkManager configuration
- `printing/` - CUPS print services
- `ssh/` - OpenSSH server
- `docker/` - Container runtime (normal/rootless)
- `tailscale/` - Tailscale VPN
- `flatpak/` - Flatpak packages
- `packages/` - System packages (base + dev + desktop + extras)
- `filesystems/` - Filesystem mounts (TrueNAS CIFS, etc.)
- `sops/` - Secrets management
- `vscode/` - Visual Studio Code with Settings Sync option
- `vpn/` - VPN clients (PIA OpenVPN)
- `security/` - Security tools (Firejail sandboxing)

**Total: 4 core + 18 feature modules = 22 modules**

## Host Templates

The `hosts/templates/` directory contains example configurations for common use cases:

- **desktop-workstation.nix** - Full desktop system with common features
- **wsl-dev.nix** - WSL development environment with VSCode Server
- **gaming-rig.nix** - Gaming-focused desktop with Steam and tools
- **minimal-server.nix** - Minimal server with SSH and Docker

To use a template:

1. Copy template to `hosts/<your-hostname>/configuration.nix`
2. Generate hardware config: `nixos-generate-config --dir hosts/<your-hostname>`
3. Customize the configuration for your needs
4. Add to `flake.nix` nixosConfigurations

## Adding New Features

To add a new feature module:

1. Create `modules/features/myfeature/default.nix`
2. Define options under `cyberfighter.features.myfeature`
3. Add module to `modules/default.nix` imports
4. Use in host configurations

Example:

```nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.myfeature;
in
{
  options.cyberfighter.features.myfeature = {
    enable = lib.mkEnableOption "My Feature";
    
    extraOptions = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Additional options";
    };
  };

  config = lib.mkIf cfg.enable {
    # Your configuration here
  };
}
```
