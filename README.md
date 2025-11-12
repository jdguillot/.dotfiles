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
         userDescription = "Your Full Name";
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

### Setting Up SOPS on a New Host

When setting up a new host, you can add its key to SOPS **directly from that host** using your personal age key stored in Bitwarden. No need to use a separate development machine!

#### Prerequisites

Install required tools on the new host:

```bash
nix-shell -p bitwarden-cli jq ssh-to-age
```

#### Step 1: Configure Bitwarden CLI (First Time Only)

If you're using a self-hosted Vaultwarden instance:

```bash
# Configure your Vaultwarden server
bw config server https://[YOUR_SERVER_ADDRESS]

# Note: You need to be on your home network or connected via Tailscale
```

#### Step 2: Authenticate with Bitwarden

```bash
# Login and get session token
export BW_SESSION=$(bw login --raw)

# Or if already logged in, just unlock
export BW_SESSION=$(bw unlock --raw)

# Sync with server
bw sync
```

#### Step 3: Set Up SOPS with Your Personal Age Key

```bash
# Get your personal age private key from Bitwarden and set as environment variable
export SOPS_AGE_KEY=$(bw get notes "SOPS Age Key")

# Verify it's set (should show your key)
echo $SOPS_AGE_KEY
```

**Alternative: Use on-demand key fetching** (more secure):

```bash
# SOPS will fetch the key automatically when needed
export SOPS_AGE_KEY_CMD='bw get notes "SOPS Age Key"'
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
unset BW_SESSION
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
nix-shell -p bitwarden-cli jq ssh-to-age --run '
  export BW_SESSION=$(bw unlock --raw) &&
  export SOPS_AGE_KEY=$(bw get notes "SOPS Age Key") &&
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
- Your personal key retrieved from Bitwarden exists only in memory (environment variable)
- No sensitive files are created on disk

### Security Benefits of This Approach

✅ **No file cleanup needed** - Age key only exists as environment variable  
✅ **Secure** - Private key never written to disk on new host  
✅ **Temporary** - Key only exists for current shell session  
✅ **Convenient** - Add hosts directly from the host itself, no dev machine needed  
✅ **Centralized** - Personal key securely stored in Bitwarden  
✅ **Auditable** - Bitwarden tracks when/where key is accessed

### Alternative: Using SOPS_AGE_KEY_CMD

For even better security, use `SOPS_AGE_KEY_CMD` which fetches the key on-demand:

```bash
export BW_SESSION=$(bw unlock --raw)
export SOPS_AGE_KEY_CMD='bw get notes "SOPS Age Key"'

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
