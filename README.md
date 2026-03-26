# NixOS Dotfiles - Complete Setup Guide

A modular NixOS configuration system with home-manager integration, featuring profiles, feature modules, secrets management, and deploy-rs for remote deployments.

## Table of Contents

- [Quick Links](#quick-links)
- [Features](#features)
- [Installation Guide](#installation-guide)
  - [Deploy-rs + Disko (Primary Method)](#deploy-rs--disko-primary-method)
  - [On a Fresh NixOS Installation (Git Clone Method)](#on-a-fresh-nixos-installation-git-clone-method)
  - [From a Live CD (Manual Partition Method)](#from-a-live-cd-manual-partition-method)
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

### System Features (26 Modules)

- **Profiles**: Desktop, WSL, Minimal - predefined configurations for common use cases
- **Desktop Environments**: Plasma6, Plasma5, GNOME, Hyprland
- **Graphics**: Nvidia (with Prime support) and AMD drivers
- **Gaming**: Steam, GameMode, MangoHud, ProtonUp-Qt, Wine
- **Containers**: Docker with rootless support
- **Networking**: NetworkManager, Tailscale VPN
- **Filesystems**: TrueNAS CIFS mounts with credentials management, Disko declarative disk partitioning
- **Security**: Firejail sandboxing, SOPS secrets management
- **Proxmox**: Proxmox VE node management via proxmox-nixos
- **Caching**: Cachix binary cache configuration
- **And more**: Bluetooth, Printing, SSH, Flatpak, Fonts, 1Password

### Home Manager Features (14 Modules)

- **Profiles**: Desktop, Minimal, WSL - automatically inherit from system profile
- **Shell**: Fish, Bash, Zsh with Starship prompt
- **Editors**: Vim, Neovim, VSCode with LazyVim support
- **Terminal**: Alacritty, Ghostty, Tmux, Zellij
- **Tools**: 40+ curated CLI tools (ripgrep, fd, fzf, bat, etc.)
- **Desktop Apps**: Firefox, 1Password, and more
- **Git**: Pre-configured with sensible defaults
- **Secrets**: SOPS home-manager secrets integration
- **SSH**: SSH client configuration with host management

## Installation Guide

### Deploy-rs + Disko (Primary Method)

This is the preferred method for deploying to remote or new systems. It uses **disko** for declarative disk partitioning and **deploy-rs** for atomic deployments with automatic rollback.

#### Prerequisites

- A working NixOS system (or NixOS live ISO) you can SSH into
- Your dotfiles repo cloned on a machine you'll deploy **from**
- The target host registered in `hosts/default.nix` and `flake.nix`

#### Step 1: Prepare the Target Host

Boot the target machine from the NixOS live ISO and enable SSH:

```bash
# On the live ISO - set a temporary root password so you can SSH in
passwd

# Note the IP address
ip addr
```

#### Step 2: Register the New Host

On your local machine, add the host to `hosts/default.nix`:

```nix
{
  # ... existing hosts ...

  your-hostname = {
    profile = "desktop";  # or "wsl", "minimal"
    system = {
      hostname = "your-hostname";
      username = "yourusername";
    };
  };
}
```

#### Step 3: Create a Disko Disk Configuration

Create `hosts/your-hostname/disk-config.nix` with your disk layout. Use an existing one as a template:

```bash
cp hosts/simple-vm/disk-config.nix hosts/your-hostname/disk-config.nix
# Edit to set the correct device (check with lsblk on the target)
```

A typical disko config (btrfs with subvolumes):

```nix
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/sda";  # Change to your disk (check with lsblk)
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
              start = "1M";
              end = "128M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              name = "root";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "/rootfs" = { mountpoint = "/"; };
                  "/home"   = { mountOptions = [ "compress=zstd" ]; mountpoint = "/home"; };
                  "/nix"    = { mountOptions = [ "compress=zstd" "noatime" ]; mountpoint = "/nix"; };
                  "/swap"   = { mountpoint = "/.swapvol"; swap.swapfile.size = "4G"; };
                };
              };
            };
          };
        };
      };
    };
  };
}
```

#### Step 4: Create the Host Configuration

Create `hosts/your-hostname/configuration.nix`:

```nix
{ inputs, ... }:
{
  imports = [
    ../../modules
    ./disk-config.nix
  ];

  cyberfighter.features = {
    desktop.environment = "plasma6";
    docker.enable = true;
    # ... other features
  };
}
```

#### Step 5: Add the Host to flake.nix

```nix
# In nixosConfigurations:
your-hostname = mkNixosSystem "your-hostname" hostConfigs.your-hostname;

# In homeConfigurations:
"yourusername@your-hostname" = mkHomeConfig "your-hostname" hostConfigs.your-hostname;

# In deploy.nodes (if using deploy-rs):
your-hostname = mkDeployNode "your-hostname" hostConfigs.your-hostname true;
```

#### Step 6: Partition and Format with Disko

From your local machine, run disko to partition and format the target disk:

```bash
# This will wipe and partition the target disk according to disk-config.nix
nix run github:nix-community/disko/latest -- \
  --mode destroy,format,mount \
  --flake .#your-hostname \
  --ssh-host root@<target-ip>
```

Or run it directly on the target (from the live ISO):

```bash
nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- \
  --mode destroy,format,mount \
  --flake github:jdguillot/.dotfiles#your-hostname
```

#### Step 7: Install NixOS

```bash
# From the live ISO (after disko has partitioned and mounted):
nixos-install --flake github:jdguillot/.dotfiles#your-hostname --no-root-password

# Reboot into the new system
reboot
```

#### Step 8: Deploy with deploy-rs

After the target reboots and SSH is available:

```bash
# Deploy system profile only
deploy .#your-hostname

# Deploy with sudo (if not root)
deploy -s .#your-hostname

# Deploy system + home-manager profiles
deploy .#your-hostname --profiles system home

# Deploy without automatic rollback (useful for debugging)
deploy .#your-hostname --auto-rollback false

# Deploy with custom SSH options
deploy .#your-hostname -- -p 2222

# Dry-run (build but don't activate)
deploy .#your-hostname --dry-activate
```

---

### On a Fresh NixOS Installation (Git Clone Method)

If you've just installed NixOS and want to use this configuration without deploy-rs:

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

4. **Register your host in hosts/default.nix** (IMPORTANT - do this first):

   ```nix
   # Edit hosts/default.nix and add your host:
   {
     # ... existing hosts ...

     your-hostname = {
       profile = "desktop";  # or "wsl", "minimal"
       system = {
         hostname = "your-hostname";
         username = "yourusername";
       };
     };
   }
   ```

5. **Generate hardware configuration**:

   ```bash
   mkdir -p hosts/<your-hostname>
   sudo nixos-generate-config --dir hosts/<your-hostname>
   ```

6. **Choose a template or create your configuration**:

   ```bash
   # Option 1: Use a template
   cp hosts/templates/desktop-workstation.nix hosts/<your-hostname>/configuration.nix

   # Option 2: Start from scratch (see Configuration System section)
   ```

7. **Edit your host configuration** (hosts/<your-hostname>/configuration.nix):

   ```nix
   # The profile, hostname, and username are already set in hosts/default.nix
   # Just configure additional features:
   {
     imports = [ ../../modules ];

     cyberfighter.features = {
       desktop.environment = "plasma6";
       docker.enable = true;
       # ... other features
     };
   }
   ```

8. **Add your host to flake.nix**:

   ```nix
   # In flake.nix nixosConfigurations section, add:
   your-hostname = mkNixosSystem "your-hostname" hostConfigs.your-hostname;
   ```

9. **Set up home-manager configuration**:

   ```bash
   mkdir -p home/<your-username>
   # Copy from home/cyberfighter/home.nix as a template
   cp home/cyberfighter/home.nix home/<your-username>/home.nix
   # Edit to match your preferences
   ```

10. **Add home-manager to flake.nix**:

    ```nix
    # In flake.nix homeConfigurations section, add:
    "yourusername@your-hostname" = mkHomeConfig "your-hostname" hostConfigs.your-hostname;
    ```

11. **Build and activate**:

    ```bash
    sudo nixos-rebuild switch --flake .#your-hostname
    ```

### From a Live CD (Manual Partition Method)

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

6. **Register your host in hosts/default.nix** (see step 4 in "On a Fresh NixOS Installation")

7. **Generate hardware configuration**:

   ```bash
   mkdir -p hosts/<your-hostname>
   sudo nixos-generate-config --root /mnt --dir hosts/<your-hostname>
   ```

8. **Create your configuration** (see "On a Fresh NixOS Installation" steps 6-10)

9. **Install NixOS**:

   ```bash
   sudo nixos-install --flake .#your-hostname

   # Set root password when prompted
   ```

10. **Reboot and finish setup**:

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

3. **Register your host in hosts/default.nix** (see step 4 in "On a Fresh NixOS Installation")

4. **Copy your hardware configuration**:

   ```bash
   mkdir -p hosts/<your-hostname>
   sudo cp /etc/nixos/hardware-configuration.nix hosts/<your-hostname>/
   ```

5. **Create new configuration** based on a template or from scratch

6. **Add your host to flake.nix** (see steps 8 and 10 in "On a Fresh NixOS Installation")

7. **Gradually migrate** your existing settings:
   - Start with a minimal profile
   - Enable features one at a time
   - Test after each change

8. **Build and test**:

   ```bash
   # Test without activating
   sudo nixos-rebuild test --flake .#your-hostname

   # If everything works, switch
   sudo nixos-rebuild switch --flake .#your-hostname
   ```

## Host Registration System

This repository uses a centralized host registration system that simplifies configuration management.

### How It Works

1. **hosts/default.nix** - Central registry of all hosts with metadata
   - Profile (desktop, wsl, minimal)
   - Hostname
   - Username
   - User description

2. **flake.nix** - Imports host metadata and generates configurations
   - Uses helper functions `mkNixosSystem` and `mkHomeConfig`
   - Automatically passes profile and metadata to configurations

3. **hosts/<hostname>/configuration.nix** - Host-specific settings
   - Only needs to configure additional features
   - Profile, hostname, and username are inherited from hosts/default.nix

### Adding a New Host

**Step 1: Register in hosts/default.nix**

```nix
{
  # ... existing hosts ...

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

**Step 2: Add to flake.nix**

```nix
# In nixosConfigurations:
my-new-host = mkNixosSystem "my-new-host" hostConfigs.my-new-host;

# In homeConfigurations:
"myuser@my-new-host" = mkHomeConfig "my-new-host" hostConfigs.my-new-host;

# Optional: In deploy.nodes (for deploy-rs remote deployment):
# mkDeployNode "hostname" hostMeta withHome
# Set withHome = true to also deploy the home-manager profile
my-new-host = mkDeployNode "my-new-host" hostConfigs.my-new-host true;
```

**Step 3: Create host configuration**

```nix
# hosts/my-new-host/configuration.nix
{
  imports = [ ../../modules ];

  # Profile, hostname, username already set via hosts/default.nix
  # Just configure features:
  cyberfighter.features = {
    desktop.environment = "plasma6";
    docker.enable = true;
  };
}
```

### Benefits of This System

- **DRY**: Define hostname and username once in hosts/default.nix
- **Consistent**: All hosts follow the same pattern
- **Simple**: Host configs only need feature configuration
- **Type-safe**: Metadata is validated and passed to all modules

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

### deploy-rs (Primary Method)

[deploy-rs](https://github.com/serokell/deploy-rs) is the primary deployment tool for remote hosts. It supports atomic deployments with automatic rollback.

#### Deploy All Profiles for a Node

```bash
# Deploy system + home-manager profiles (order defined by profilesOrder in flake.nix)
deploy .#hostname
```

#### Deploy with sudo (recommended for non-root SSH users)

```bash
deploy -s .#hostname
# Equivalent to:
deploy --sudo .#hostname
```

#### Deploy a Specific Profile

```bash
# System profile only
deploy .#hostname --profiles system

# Home-manager profile only
deploy .#hostname --profiles home

# Both (explicit order)
deploy .#hostname --profiles system home
```

#### Rollback Control

```bash
# Disable automatic rollback (useful when debugging activation failures)
deploy .#hostname --auto-rollback false

# Default behavior is to auto-rollback on failure
deploy .#hostname  # --auto-rollback true is the default
```

#### Dry Run / Build Only

```bash
# Build without activating (verify the config builds)
deploy .#hostname --dry-activate
```

#### Custom SSH Options

```bash
# Use a non-standard SSH port
deploy .#hostname -- -p 2222

# Use a specific SSH key
deploy .#hostname -- -i ~/.ssh/id_ed25519
```

#### Deploy All Configured Nodes

```bash
# Deploy to all nodes defined in deploy.nodes
deploy .
```

#### Available Deploy Nodes

| Node | Profiles | Description |
|------|----------|-------------|
| `thkpd-pve1` | system + home | Proxmox VE node |
| `simple-vm` | system | Minimal VM |
| `sys-galp-nix` | system + home | Laptop |

### Local Build Commands (nixos-rebuild)

For local (on-machine) deployments, use the standard `nixos-rebuild` workflow:

```bash
# Build and activate NixOS system
sudo nixos-rebuild switch --flake .#hostname
# Or use alias:
ns

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

| Hostname | Profile | Description |
|----------|---------|-------------|
| `razer-nixos` | desktop | Desktop workstation |
| `sys-galp-nix` | desktop | Laptop |
| `work-nix-wsl` | wsl | Work WSL environment |
| `ryzn-nix-wsl` | wsl | Personal WSL environment |
| `nixos-portable` | desktop | Portable installation |
| `thkpd-pve1` | minimal | Proxmox VE node |
| `simple-vm` | minimal | Minimal VM |

## Secrets Management

This repository uses **SOPS** (Secrets OPerationS) with age encryption for managing secrets.

### Setting Up SOPS on a New Host

When setting up a new host, you can add its key to SOPS **directly from that host** using your personal age key stored in 1Password. No need to use a separate development machine!

#### Prerequisites

Install required tools on the new host:

```bash
nix-shell -p _1password-cli jq ssh-to-age
```

#### Step 1: Sign In to 1Password CLI

```bash
# Sign in and get session token
eval $(op signin)
```

#### Step 2: Set Up SOPS with Your Personal Age Key

```bash
# Get your personal age private key from 1Password and set as environment variable
export SOPS_AGE_KEY=$(op read "op://Personal/SOPS Age Key/notesPlain")

# Verify it's set (should show your key)
echo $SOPS_AGE_KEY
```

**Alternative: Use on-demand key fetching** (more secure):

```bash
# SOPS will fetch the key automatically when needed
export SOPS_AGE_KEY_CMD='op read "op://Personal/SOPS Age Key/notesPlain"'
```

#### Step 4: Get New Host's Age Public Key

```bash
# Generate age public key from the host's SSH key
nix-shell -p ssh-to-age --run 'cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age'

# Output example:
# age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

#### Step 5: Add New Host Key to .sops.yaml

Edit `.sops.yaml` (now you can use SOPS since you have your personal key):

```yaml
keys:
  - &cyberfighter age1059cfeyzas7ug20q7w39vwr8v9vj8rylxmhwl4p4uzh90hknyprq359wyd
  - &razer-nix age1g98hga3gn0qmtelwmcm3gpfpjpmt6zs60xww2vj7fk4v8n48qc5shnnvq3
  # Add your new host key:
  - &my-new-host age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

creation_rules:
  - path_regex: secrets/secrets.yaml$
    key_groups:
      - age:
          - *cyberfighter
          - *razer-nix
          - *my-new-host # Add reference here
```

#### Step 6: Re-encrypt Secrets with New Host Key

```bash
# Re-encrypt secrets to include the new host
sops updatekeys secrets/secrets.yaml
```

You should see output like:

```
2022/02/09 16:32:02 Syncing keys for file secrets/secrets.yaml
The following changes will be made to the file's groups:
Group 1
    age1059cfeyzas7ug20q7w39vwr8v9vj8rylxmhwl4p4uzh90hknyprq359wyd
    age1g98hga3gn0qmtelwmcm3gpfpjpmt6zs60xww2vj7fk4v8n48qc5shnnvq3
+++ age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
Is this okay? (y/n): y
```

#### Step 7: Commit and Push

```bash
# Commit the updated configuration
git add .sops.yaml secrets/secrets.yaml
git commit -m "Add SOPS key for my-new-host"
git push
```

#### Step 8: Clean Up Environment Variables

```bash
# Remove sensitive data from environment
unset SOPS_AGE_KEY
unset SOPS_AGE_KEY_CMD
```

#### Step 9: Verify Secrets Work

```bash
# Rebuild the system
sudo nixos-rebuild switch --flake .#my-new-host

# Check that secrets are available
ls -l /run/secrets/

# Test a specific secret
cat /run/secrets/my-secret
```

### Quick Reference: One-Command Workflow

```bash
# Complete workflow in one go:
nix-shell -p _1password-cli ssh-to-age --run '
  eval $(op signin) &&
  export SOPS_AGE_KEY=$(op read "op://Personal/SOPS Age Key/notesPlain") &&
  echo "New host key:" &&
  cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age &&
  echo "Now edit .sops.yaml to add this key, then run:" &&
  echo "  sops updatekeys secrets/secrets.yaml"
'
```

### Why This Works

- **Your personal age key** (`&cyberfighter`) allows YOU to edit secrets from any machine
- **Host keys** (like `&razer-nix`, `&my-new-host`) allow HOSTS to decrypt secrets at runtime
- You use your personal key to edit/re-encrypt, hosts use their keys to decrypt
- Your personal key retrieved from 1Password exists only in memory (environment variable)
- No sensitive files are created on disk

### Security Benefits of This Approach

✅ **No file cleanup needed** - Age key only exists as environment variable  
✅ **Secure** - Private key never written to disk on new host  
✅ **Temporary** - Key only exists for current shell session  
✅ **Convenient** - Add hosts directly from the host itself, no dev machine needed  
✅ **Centralized** - Personal key securely stored in 1Password  
✅ **Auditable** - 1Password tracks when/where key is accessed

### Alternative: Using SOPS_AGE_KEY_CMD

For even better security, use `SOPS_AGE_KEY_CMD` which fetches the key on-demand:

```bash
eval $(op signin)
export SOPS_AGE_KEY_CMD='op read "op://Personal/SOPS Age Key/notesPlain"'

# SOPS will fetch your key automatically when needed
sops secrets/secrets.yaml
```

This ensures the key is only retrieved when SOPS actually needs it.

### Common Operations

```bash
# Edit secrets
sops secrets/secrets.yaml

# Add a new secret
# 1. Edit secrets/secrets.yaml with sops
# 2. Add the secret key-value pair
# 3. Save and commit

# View secrets (decrypted)
sops secrets/secrets.yaml

# Re-encrypt after adding new host
sops updatekeys secrets/secrets.yaml
```

### Using Secrets in Configuration

Enable SOPS in your host configuration:

```nix
cyberfighter.features.sops = {
  enable = true;
  defaultSopsFile = ../../secrets/secrets.yaml;
};
```

Define secrets to use:

```nix
# Make secret available
config.sops.secrets."my-secret" = { };

# Secret will be available at: /run/secrets/my-secret

# Use in a service
services.myservice = {
  passwordFile = config.sops.secrets."my-secret".path;
};
```

### Troubleshooting

**Error: "Failed to get the data key"**

- Your host key is not in `.sops.yaml`
- Run `sops updatekeys secrets/secrets.yaml` after adding the key

**Error: "no such file or directory: /etc/ssh/ssh_host_ed25519_key"**

- Host doesn't have an ed25519 SSH key
- Generate one: `sudo ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""`

**Secrets not appearing in /run/secrets/**

- SOPS module not enabled in configuration
- Add: `cyberfighter.features.sops.enable = true;`

See **[docs/SOPS-MIGRATION.md](docs/SOPS-MIGRATION.md)** for complete secrets management guide.

## Module Documentation

### Detailed References

- **[NixOS Modules](docs/MODULES.md)** - Complete system module options, types, defaults, and examples
- **[Home Manager Modules](docs/HOME-MANAGER.md)** - Complete home-manager options, types, defaults, and examples

### Module Organization

**NixOS Modules (26 total)**:

- **Core** (4): profiles, system, users, nix-settings
- **Features** (22): 1password, bluetooth, cachix, desktop, docker, filesystems, flatpak, fonts, gaming, graphics, networking, packages, printing, proxmox, security, sops, sound, ssh, tailscale, vpn, vscode, wine

**Home Manager Modules (14 total)**:

- **Core** (6): common, profiles, system, users, packages, wsl
- **Features** (8): git, shell, editor, terminal, desktop, tools, sops, ssh

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

### Learning Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Nix Pills](https://nixos.org/guides/nix-pills/)
- [Zero to Nix](https://zero-to-nix.com/)
- [deploy-rs Documentation](https://github.com/serokell/deploy-rs)
- [disko Documentation](https://github.com/nix-community/disko)

## Repository Structure

```
.
├── flake.nix           # Flake configuration (nixosConfigurations, homeConfigurations, deploy.nodes)
├── flake.lock          # Locked flake inputs
├── README.md           # This file
├── hosts/              # Host-specific configurations
│   ├── default.nix     # Centralized host metadata registry
│   ├── razer-nixos/    # Desktop workstation  (flake key: razer-nixos)
│   ├── sys-galp-nix/   # Laptop (deploy-rs managed)  (flake key: sys-galp-nix)
│   ├── thkpd-pve1/     # Proxmox VE node (deploy-rs managed, disko)  (flake key: thkpd-pve1)
│   ├── simple-vm/      # Minimal VM (deploy-rs managed, disko)  (flake key: simple-vm)
│   ├── work-wsl/       # Work WSL environment  (flake key: work-nix-wsl)
│   ├── ryzn-wsl/       # Personal WSL environment  (flake key: ryzn-nix-wsl)
│   ├── nixos-portable/ # Portable installation  (flake key: nixos-portable)
│   └── templates/      # Example configurations
├── modules/            # NixOS system modules
│   ├── core/           # Essential modules (profiles, system, users, nix-settings)
│   └── features/       # Optional features (22 modules)
├── home/               # Home-manager configurations
│   ├── modules/        # Home-manager modules (14 total)
│   ├── cyberfighter/   # cyberfighter user home config
│   └── jdguillot/      # jdguillot user home config
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
