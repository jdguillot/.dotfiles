# NixOS Dotfiles - Complete Setup Guide

A modular NixOS configuration system with home-manager integration, featuring profiles, feature modules, and secrets management.

## Table of Contents

- [Quick Links](#quick-links)
- [Features](#features)
- [Installation Guide](#installation-guide)
  - [On a Fresh NixOS Installation](#on-a-fresh-nixos-installation)
  - [From a Live CD](#from-a-live-cd)
  - [On an Existing System](#on-an-existing-system)
- [Configuration System](#configuration-system)
- [Quick Start Examples](#quick-start-examples)
- [Building and Deploying](#building-and-deploying)
- [Secrets Management](#secrets-management)
- [Module Documentation](#module-documentation)

## Quick Links

- **[NixOS Modules Reference](docs/MODULES.md)** - Complete NixOS system module documentation
- **[Home Manager Reference](docs/HOME-MANAGER.md)** - Complete home-manager module documentation
- **[SOPS Secrets Guide](docs/SOPS-MIGRATION.md)** - Secrets management with SOPS

## Features

### System Features (22 Modules)

- **Profiles**: Desktop, WSL, Minimal - predefined configurations for common use cases
- **Desktop Environments**: Plasma6, Plasma5, GNOME, Hyprland
- **Graphics**: Nvidia (with Prime support) and AMD drivers
- **Gaming**: Steam, GameMode, MangoHud, ProtonUp-Qt
- **Containers**: Docker with rootless support
- **Networking**: NetworkManager, Tailscale VPN
- **Filesystems**: TrueNAS CIFS mounts with credentials management
- **Security**: Firejail sandboxing, SOPS secrets management
- **And more**: Bluetooth, Printing, SSH, Flatpak, Fonts

### Home Manager Features (10 Modules)

- **Profiles**: Desktop, Minimal, WSL - automatically inherit from system profile
- **Shell**: Fish, Bash, Zsh with Starship prompt
- **Editors**: Vim, Neovim, VSCode with LazyVim support
- **Terminal**: Alacritty, Ghostty, Tmux, Zellij
- **Tools**: 40+ curated CLI tools (ripgrep, fd, fzf, bat, etc.)
- **Desktop Apps**: Firefox, Bitwarden, and more
- **Git**: Pre-configured with sensible defaults

## Installation Guide

### On a Fresh NixOS Installation

If you've just installed NixOS and want to use this configuration:

1. **Boot into your new NixOS system**

2. **Install required tools** (if not already available):
   ```bash
   nix-shell -p git gh
   ```

3. **Clone this repository**:
   ```bash
   git clone https://github.com/jdguillot/.dotfiles.git ~/dotfiles
   cd ~/dotfiles
   ```

4. **Generate hardware configuration**:
   ```bash
   # For a new host
   mkdir -p hosts/<your-hostname>
   sudo nixos-generate-config --dir hosts/<your-hostname>
   ```

5. **Choose a template or create your configuration**:
   ```bash
   # Option 1: Use a template
   cp hosts/templates/desktop-workstation.nix hosts/<your-hostname>/configuration.nix
   
   # Option 2: Start from scratch (see Configuration System section)
   ```

6. **Edit your configuration**:
   ```bash
   # Edit hosts/<your-hostname>/configuration.nix
   # Set at minimum:
   # - cyberfighter.system.hostname
   # - cyberfighter.system.username
   # - Choose a profile (desktop, wsl, minimal)
   ```

7. **Add your host to flake.nix**:
   ```nix
   # In flake.nix, add to nixosConfigurations:
   your-hostname = nixpkgs.lib.nixosSystem {
     inherit system;
     specialArgs = { inherit inputs; };
     modules = [
       ./hosts/your-hostname/configuration.nix
       home-manager.nixosModules.home-manager
       {
         home-manager.useGlobalPkgs = true;
         home-manager.useUserPackages = true;
         home-manager.extraSpecialArgs = { inherit inputs; };
         home-manager.users.${yourUsername} = import ./home/${yourUsername}/home.nix;
       }
     ];
   };
   ```

8. **Set up home-manager configuration**:
   ```bash
   mkdir -p home/<your-username>
   # Copy from home/cyberfighter/home.nix as a template
   cp home/cyberfighter/home.nix home/<your-username>/home.nix
   # Edit to match your preferences
   ```

9. **Build and activate**:
   ```bash
   sudo nixos-rebuild switch --flake .#your-hostname
   ```

### From a Live CD

Installing NixOS from scratch with this configuration:

1. **Boot the NixOS installation media**

2. **Connect to the internet**:
   ```bash
   # For WiFi
   sudo systemctl start wpa_supplicant
   wpa_cli
   > add_network
   > set_network 0 ssid "YOUR_SSID"
   > set_network 0 psk "YOUR_PASSWORD"
   > enable_network 0
   > quit
   
   # Or use nmtui for an easier interface
   nmtui
   ```

3. **Partition your disk** (example with UEFI):
   ```bash
   # List disks
   lsblk
   
   # Partition (example for /dev/sda)
   sudo parted /dev/sda -- mklabel gpt
   sudo parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB
   sudo parted /dev/sda -- set 1 esp on
   sudo parted /dev/sda -- mkpart primary 512MiB 100%
   
   # Format partitions
   sudo mkfs.fat -F 32 -n boot /dev/sda1
   sudo mkfs.ext4 -L nixos /dev/sda2
   
   # Mount
   sudo mount /dev/disk/by-label/nixos /mnt
   sudo mkdir -p /mnt/boot
   sudo mount /dev/disk/by-label/boot /mnt/boot
   ```

4. **For encrypted root** (optional):
   ```bash
   # Encrypt root partition
   sudo cryptsetup luksFormat /dev/sda2
   sudo cryptsetup open /dev/sda2 cryptroot
   sudo mkfs.ext4 -L nixos /dev/mapper/cryptroot
   sudo mount /dev/mapper/cryptroot /mnt
   
   # Note the UUID for later
   sudo cryptsetup luksUUID /dev/sda2
   ```

5. **Install git and clone dotfiles**:
   ```bash
   nix-shell -p git gh
   cd /mnt
   git clone https://github.com/jdguillot/.dotfiles.git /mnt/home/dotfiles
   cd /mnt/home/dotfiles
   ```

6. **Generate hardware configuration**:
   ```bash
   mkdir -p hosts/<your-hostname>
   sudo nixos-generate-config --root /mnt --dir hosts/<your-hostname>
   ```

7. **Create your configuration** (see "On a Fresh NixOS Installation" step 5-8)

8. **Install NixOS**:
   ```bash
   sudo nixos-install --flake .#your-hostname
   
   # Set root password when prompted
   ```

9. **Reboot and finish setup**:
   ```bash
   reboot
   # After reboot, log in and run:
   sudo nixos-rebuild switch --flake ~/dotfiles#your-hostname
   ```

### On an Existing System

Migrating an existing NixOS system to this configuration:

1. **Backup your current configuration**:
   ```bash
   sudo cp -r /etc/nixos /etc/nixos.backup
   ```

2. **Clone this repository**:
   ```bash
   git clone https://github.com/jdguillot/.dotfiles.git ~/dotfiles
   cd ~/dotfiles
   ```

3. **Copy your hardware configuration**:
   ```bash
   mkdir -p hosts/<your-hostname>
   sudo cp /etc/nixos/hardware-configuration.nix hosts/<your-hostname>/
   ```

4. **Create new configuration** based on a template or from scratch

5. **Gradually migrate** your existing settings:
   - Start with a minimal profile
   - Enable features one at a time
   - Test after each change

6. **Build and test**:
   ```bash
   # Test without activating
   sudo nixos-rebuild test --flake .#your-hostname
   
   # If everything works, switch
   sudo nixos-rebuild switch --flake .#your-hostname
   ```

## Configuration System

This repository uses a modular configuration system under the `cyberfighter` namespace.

### NixOS Configuration Structure

```nix
{
  imports = [ ../../modules ];
  
  cyberfighter = {
    # Choose a profile (optional but recommended)
    profile.enable = "desktop";  # or "wsl", "minimal", "none"
    
    # Core system settings
    system = {
      hostname = "my-nixos";
      username = "myuser";
      userDescription = "My Full Name";
      stateVersion = "25.05";
      
      # Bootloader configuration
      bootloader = {
        systemd-boot = true;
        efiCanTouchVariables = true;
        # luksDevice = "uuid-here";  # Optional: for encrypted disks
      };
      
      extraGroups = [ "docker" ];  # Additional user groups
    };
    
    # Nix configuration
    nix = {
      trustedUsers = [ "root" "myuser" ];
      enableDevenv = true;
    };
    
    # Package selection
    packages = {
      includeBase = true;
      includeDesktop = true;
      extraPackages = with pkgs; [
        # htop  # Example - base already includes htop
        # neofetch  # Add your custom packages here
      ];
    };
    
    # Feature modules
    features = {
      # Desktop environment
      desktop = {
        environment = "plasma6";  # or "gnome", "hyprland", etc.
        firefox = true;
      };
      
      # Graphics drivers
      graphics = {
        enable = true;
        nvidia = {
          enable = true;
          # prime = {
          #   enable = true;
          #   intelBusId = "PCI:0:2:0";
          #   nvidiaBusId = "PCI:2:0:0";
          # };
        };
      };
      
      # Sound
      sound.enable = true;
      
      # Fonts
      fonts.enable = true;
      
      # Bluetooth
      # bluetooth = {
      #   enable = true;
      #   powerOnBoot = true;
      # };
      
      # Gaming
      # gaming = {
      #   enable = true;
      #   steam.enable = true;
      #   gamemode = true;
      #   mangohud = true;
      # };
      
      # Containers
      docker.enable = true;
      
      # VPN
      # tailscale = {
      #   enable = true;
      #   acceptRoutes = true;
      # };
      
      # Flatpak applications
      flatpak = {
        enable = true;
        browsers = true;  # Zen Browser, Chromium
        # cad = true;  # OpenSCAD, FreeCAD
        # electronics = true;  # Arduino IDE, Fritzing
        extraPackages = [
          # "com.moonlight_stream.Moonlight"
          # "us.zoom.Zoom"
        ];
      };
      
      # Network file systems
      # filesystems.truenas = {
      #   enable = true;
      #   mounts = {
      #     home = {
      #       share = "userdata/myuser";
      #       mountPoint = "/mnt/nas-home";
      #     };
      #   };
      # };
    };
  };
}
```

### Home Manager Configuration Structure

```nix
{
  imports = [
    ../modules
    # Optional: Import additional feature configurations
    # ../features/cli/lazyvim/lazyvim.nix
    # ../features/cli/tmux/default.nix
    # ../features/desktop/alacritty/default.nix
  ];
  
  cyberfighter = {
    # Profile auto-inherits from system (optional override)
    # profile.enable = "desktop";
    
    # User settings
    system = {
      username = "myuser";
      homeDirectory = "/home/myuser";
      stateVersion = "24.11";
    };
    
    # Packages
    packages = {
      includeDev = true;  # Development tools
      extraPackages = with pkgs; [
        # Add your custom packages
      ];
    };
    
    # Features
    features = {
      # Git configuration
      git = {
        userName = "Your Name";
        userEmail = "your@email.com";
      };
      
      # Shell configuration
      shell = {
        fish.enable = true;
        starship.enable = true;
        # extraAliases = {
        #   vi = "nvim";
        # };
      };
      
      # Editor configuration
      editor = {
        neovim.enable = true;
        # vscode.enable = true;
      };
      
      # Terminal (auto-enabled on desktop systems)
      terminal = {
        # alacritty.enable = true;
        # tmux.enable = true;
      };
      
      # Desktop apps (auto-enabled on desktop systems)
      desktop = {
        firefox.enable = true;
        bitwarden.enable = true;
      };
      
      # Development tools
      tools = {
        enableDefault = true;  # Includes 40+ CLI tools
        # extraPackages = with pkgs; [ kubectl ];
      };
    };
  };
  
  programs.home-manager.enable = true;
}
```

## Quick Start Examples

### Desktop Workstation

```nix
{
  cyberfighter = {
    profile.enable = "desktop";
    
    system = {
      hostname = "workstation";
      username = "myuser";
    };
    
    features = {
      desktop.environment = "plasma6";
      docker.enable = true;
      gaming.enable = true;
    };
  };
}
```

### WSL Development Environment

```nix
{
  cyberfighter = {
    profile.enable = "wsl";
    
    system = {
      hostname = "dev-wsl";
      username = "devuser";
    };
    
    features = {
      docker.enable = true;
      tailscale.enable = true;
    };
  };
}
```

### Gaming Rig

```nix
{
  cyberfighter = {
    profile.enable = "desktop";
    
    system = {
      hostname = "gaming-pc";
      username = "gamer";
    };
    
    features = {
      desktop.environment = "plasma6";
      graphics = {
        enable = true;
        nvidia.enable = true;
      };
      gaming = {
        enable = true;
        steam = {
          enable = true;
          remotePlay = true;
          gamescopeSession = true;
        };
        gamemode = true;
        mangohud = true;
      };
    };
  };
}
```

### Minimal Server

```nix
{
  cyberfighter = {
    profile.enable = "minimal";
    
    system = {
      hostname = "server";
      username = "admin";
    };
    
    features = {
      ssh = {
        enable = true;
        passwordAuth = false;
        permitRootLogin = "no";
      };
      docker.enable = true;
    };
  };
}
```

## Building and Deploying

### Build Commands

```bash
# Build and activate NixOS + home-manager
sudo nixos-rebuild switch --flake .#hostname
# Or use alias:
ns

# Build NixOS only
sudo nixos-rebuild switch --flake .#hostname

# Build home-manager only
home-manager switch --flake .#user@host
# Or use alias:
hs

# Test without activating
sudo nixos-rebuild test --flake .#hostname

# Build for next boot
sudo nixos-rebuild boot --flake .#hostname

# Update flake inputs
nix flake update
# Or use alias:
nu

# Show flake outputs
nix flake show
```

### Available Hosts

- `razer-nixos` - Desktop workstation
- `sys-galp-nix` - Laptop
- `work-wsl` - Work WSL environment
- `ryzn-wsl` - Personal WSL environment
- `nixos-portable` - Portable installation

## Secrets Management

This repository uses **SOPS** (Secrets OPerationS) with age encryption for managing secrets.

### Quick Start with Secrets

1. **Secrets are automatically decrypted** at runtime on configured hosts
2. **No manual unlock required** - SOPS uses SSH host keys

### Common Operations

```bash
# Edit secrets
sops secrets/secrets.yaml

# Add a new secret
# 1. Edit secrets/secrets.yaml
# 2. Add the secret key-value pair
# 3. Save and commit

# Configure secrets in your configuration
cyberfighter.features.sops = {
  enable = true;
  defaultSopsFile = ../../secrets/secrets.yaml;
};

# Use secrets in configuration
config.sops.secrets."my-secret" = { };
# Secret will be available at: /run/secrets/my-secret
```

See **[docs/SOPS-MIGRATION.md](docs/SOPS-MIGRATION.md)** for complete secrets management guide.

## Module Documentation

### Detailed References

- **[NixOS Modules](docs/MODULES.md)** - Complete system module options, types, defaults, and examples
- **[Home Manager Modules](docs/HOME-MANAGER.md)** - Complete home-manager options, types, defaults, and examples

### Module Organization

**NixOS Modules (22 total)**:
- **Core** (4): profiles, system, users, nix-settings
- **Features** (18): desktop, graphics, sound, fonts, bluetooth, gaming, networking, printing, ssh, docker, tailscale, flatpak, packages, filesystems, sops, vscode, vpn, security

**Home Manager Modules (10 total)**:
- **Core** (5): common, profiles, system, users, packages
- **Features** (5): git, shell, editor, terminal, desktop, tools

### Profile Defaults

**Desktop Profile** enables:
- Desktop environment, Graphics, Sound, NetworkManager
- Base + Desktop packages, Flatpak with common apps
- Systemd-boot bootloader

**WSL Profile** enables:
- Graphics (for GUI apps)
- Base packages only
- Disables bootloader and NetworkManager

**Minimal Profile** enables:
- NetworkManager, Systemd-boot
- Base packages only

## Help and Support

### Quick Actions

Press `Ctrl+P` in your terminal for available actions (if using OpenCode)

### Feedback

Report issues at: https://github.com/sst/opencode

### Learning Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Nix Pills](https://nixos.org/guides/nix-pills/)
- [Zero to Nix](https://zero-to-nix.com/)

## Repository Structure

```
.
├── flake.nix           # Flake configuration
├── flake.lock          # Locked flake inputs
├── README.md           # This file
├── hosts/              # Host-specific configurations
│   ├── razer-nixos/
│   ├── sys-galp-nix/
│   ├── work-wsl/
│   ├── ryzn-wsl/
│   └── templates/      # Example configurations
├── modules/            # NixOS system modules
│   ├── core/           # Essential modules
│   └── features/       # Optional features
├── home/               # Home-manager configurations
│   ├── modules/        # Home-manager modules
│   ├── features/       # Feature implementations
│   ├── cyberfighter/
│   └── jdguillot/
├── secrets/            # SOPS encrypted secrets
├── docs/               # Documentation
│   ├── MODULES.md
│   ├── HOME-MANAGER.md
│   └── SOPS-MIGRATION.md
└── scripts/            # Utility scripts
```

## Contributing

This is a personal dotfiles repository, but feel free to:
- Use it as inspiration for your own configuration
- Submit issues for bugs or unclear documentation
- Suggest improvements via pull requests

## License

This configuration is provided as-is for personal and educational use.
