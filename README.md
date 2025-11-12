# NixOS Setup Guide

## Configuration System

This dotfiles repository uses a modular configuration system under the `cyberfighter` namespace for both NixOS and home-manager.

### NixOS Modules

- **Core Modules** (`modules/core/`) - Essential configuration (profiles, system, users, nix-settings)
- **Feature Modules** (`modules/features/`) - Optional features (desktop, gaming, bluetooth, docker, etc.)

See [docs/MODULES.md](docs/MODULES.md) for detailed NixOS module documentation.

### Home Manager Modules

- **Core Modules** (`home/modules/core/`) - Essential home configuration (profiles, system, packages)
- **Feature Modules** (`home/modules/features/`) - Optional features (git, shell, editor, terminal, desktop, tools)

See [docs/HOME-MANAGER.md](docs/HOME-MANAGER.md) for detailed home-manager module documentation.

### Quick Example

```nix
{
  imports = [ ../../modules ];
  
  cyberfighter = {
    profile.enable = "desktop";  # Auto-configures desktop, graphics, sound, packages
    
    system = {
      hostname = "my-nixos";
      username = "myuser";
      extraGroups = [ "docker" ];
    };
    
    nix.trustedUsers = [ "root" "myuser" ];
    
    features = {
      desktop.environment = "plasma6";  # or "gnome", "hyprland"
      bluetooth.enable = true;
      gaming.enable = true;
      docker.enable = true;
      
      flatpak.extraPackages = [ "com.spotify.Client" ];
    };
  };
}
```

### Available NixOS Profiles

- **desktop** - Full desktop with graphics, sound, NetworkManager, common packages & flatpaks
- **wsl** - WSL-optimized with graphics support for GUI apps
- **minimal** - Basic system with networking

### Home Manager Quick Example

```nix
{
  imports = [ ../modules ];
  
  cyberfighter = {
    profile.enable = "desktop";
    
    system = {
      username = "myuser";
      homeDirectory = "/home/myuser";
      stateVersion = "24.11";
    };
    
    features = {
      git = {
        enable = true;
        userName = "My Name";
        userEmail = "my@email.com";
      };
      
      shell = {
        enable = true;
        fish.enable = true;
        starship.enable = true;
      };
      
      editor = {
        enable = true;
        neovim.enable = true;
      };
      
      desktop.enable = true;
      tools.enable = true;
    };
  };
}
```

### Key Features

- **NixOS**: 22 Total Modules (4 core + 18 feature modules)
- **Home Manager**: 12 Total Modules (4 core + 6 feature modules + 2 profile options)
- **Type-Safe** - All options have proper types and defaults
- **DRY** - Common configurations defined once, reused everywhere
- **Flexible** - Profile defaults can be overridden per-host/user
- **Clean** - Import just `../../modules` or `../modules` to get everything
- **Templates** - Example configs in `hosts/templates/` for quick setup
- **Unified** - Same configuration pattern for both NixOS and home-manager

## Obtaining Everything

### Get some basic packages

If the system does not already have git and gh then start with the following command.

```bash
nix-shell -p git gh
```

### Clone the Repo

```bash
git clone https://github.com/jdguillot/.dotfiles.git
```

### Secrets Management

This repository uses **SOPS** (Secrets OPerationS) for managing secrets with age encryption.

**Note:** Secrets are automatically decrypted at runtime on configured hosts. No manual unlock step is needed.

See [docs/SOPS-MIGRATION.md](docs/SOPS-MIGRATION.md) for:
- How to add secrets
- How to configure new hosts
- How to edit secrets with `sops secrets/secrets.yaml`
