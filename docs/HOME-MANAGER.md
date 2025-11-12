# Home Manager Module System

This document describes the modular home-manager configuration system used in this repository.

## Overview

The home-manager configurations are organized into a modular system similar to the NixOS system modules and **automatically inherit settings from the host NixOS configuration**:

- **Core Modules**: Essential configuration options for home-manager
- **Feature Modules**: Optional features that can be enabled per user
- **Host Integration**: Profile and desktop settings automatically follow the host configuration

## Directory Structure

```
home/
├── modules/
│   ├── core/              # Core home-manager modules
│   │   ├── packages/      # Package management
│   │   ├── profiles/      # User profiles (desktop, minimal, wsl)
│   │   ├── system/        # System settings (username, home directory)
│   │   └── users/         # User-specific settings
│   └── features/          # Feature modules
│       ├── desktop/       # Desktop applications
│       ├── editor/        # Editor configurations
│       ├── git/           # Git configuration
│       ├── shell/         # Shell configuration
│       ├── terminal/      # Terminal emulator settings
│       └── tools/         # Development and utility tools
├── cyberfighter/          # User-specific configurations
│   └── home.nix
├── jdguillot/
│   └── home.nix
├── features/              # Legacy feature implementations
│   ├── cli/               # CLI application configs
│   └── desktop/           # Desktop application configs
└── common/                # Shared configurations

```

## Core Modules

### Profiles

Define the type of environment. **Automatically inherits from the host NixOS configuration if available.**

- `desktop` - Full desktop environment
- `minimal` - Minimal command-line only
- `wsl` - WSL-specific configuration

Example:
```nix
# Profile is automatically set based on host
# If host has cyberfighter.profile.enable = "desktop", home-manager will use "desktop"
# Manual override:
cyberfighter.profile.enable = "minimal";  # Force minimal profile
```

### System

User and home directory settings:
- `username` - User account name
- `homeDirectory` - Home directory path
- `stateVersion` - Home Manager state version

### Packages

Package management:
- `includeDev` - Include development packages (gcc, python3, etc.)
- `extraPackages` - Additional packages to install

## Feature Modules

### Git (`features.git`)

Git configuration options:
```nix
cyberfighter.features.git = {
  enable = true;
  userName = "your-name";
  userEmail = "your-email@example.com";
  extraSettings = { };
};
```

### Shell (`features.shell`)

Shell and prompt configuration:
```nix
cyberfighter.features.shell = {
  enable = true;
  fish = {
    enable = true;
    plugins = [ ... ];
  };
  bash.enable = false;
  zsh.enable = false;
  starship.enable = true;
  extraSessionVariables = { };
  extraAliases = { };
};
```

Default aliases include:
- `ls` → eza with icons and tree view
- `ll` → ls -la
- `ns` → nixos-rebuild + home-manager switch
- `hs` → home-manager switch
- `nu` → nix flake update
- `nb` → nixos-rebuild boot + home-manager switch

### Editor (`features.editor`)

Editor configurations:
```nix
cyberfighter.features.editor = {
  enable = true;
  vim.enable = false;
  neovim.enable = true;
  vscode = {
    enable = false;
    extensions = [ ];
  };
};
```

**Note**: For LazyVim configuration, import the existing `../features/cli/lazyvim/lazyvim.nix` file.

### Terminal (`features.terminal`)

Terminal emulator and multiplexer settings. **Automatically enables if the host has a desktop environment.**

```nix
cyberfighter.features.terminal = {
  enable = true;  # Auto-enabled if host has desktop environment
  alacritty.enable = false;
  ghostty.enable = false;
  tmux.enable = false;
  zellij = {
    enable = true;
    theme = "nord";
    font = "FiraCode Nerd Font";
  };
};
```

**Auto-detection:**
- Checks if `osConfig.cyberfighter.features.desktop.enable` is true
- Terminal emulators auto-enable on desktop systems
- Stays disabled on headless servers

**Note**: For full Alacritty, Ghostty, and Tmux configurations, import the existing feature files from `../features/`.

### Desktop (`features.desktop`)

Desktop application settings. **Automatically enables if the host has a desktop environment configured.**

```nix
cyberfighter.features.desktop = {
  enable = true;  # Auto-enabled if host has cyberfighter.features.desktop.enable = true
  firefox = {
    enable = true;
    package = pkgs.firefox;
  };
  bitwarden.enable = true;
  extraPackages = [ ];
};
```

**Auto-detection:**
- Checks if `osConfig.cyberfighter.features.desktop.enable` is true
- If true, desktop features are automatically enabled
- On headless servers or minimal hosts, desktop features stay disabled

Includes by default:
- bottles
- super-productivity
- vivaldi
- qbittorrent

### Tools (`features.tools`)

Development and utility tools:
```nix
cyberfighter.features.tools = {
  enable = true;
  enableDefault = true;  # Include default tool set
  extraPackages = [ ];
};
```

Default tools include:
- **Editors**: micro, zed-editor, neovim
- **File Management**: eza, fd, duf, tree, yazi
- **Development**: ripgrep, jq, fx, tree-sitter
- **Network**: dig, gh
- **Fun**: cowsay, lolcat, fortune, cmatrix, cbonsai, asciiquarium
- **Containers**: distrobox, lazydocker
- **And more**: tldr, fzf, bat, zoxide, cht-sh, posting, etc.

## User Configuration Example

### Desktop User (cyberfighter on razer-nixos)

```nix
{
  imports = [
    ../modules
    ../features/cli/jujutsu.nix
    ../features/cli/lazyvim/lazyvim.nix
    ../features/cli/btop/btop.nix
    ../features/cli/lazygit/default.nix
    ../features/cli/starship/default.nix
    ../features/cli/tmux/default.nix
    ../features/desktop/alacritty/default.nix
    ../features/desktop/ghostty/default.nix
    ../features/desktop/bitwarden.nix
  ];

  cyberfighter = {
    # Profile automatically inherits "desktop" from razer-nixos host
    # profile.enable is auto-set to "desktop"

    system = {
      username = "cyberfighter";
      homeDirectory = "/home/cyberfighter";
      stateVersion = "24.11";
    };

    packages = {
      includeDev = true;
      extraPackages = with pkgs; [
        inputs.isd.packages.${pkgs.system}.default
      ];
    };

    features = {
      # Git, shell, editor, and tools are enabled by default (no need to set enable = true)
      git = {
        userName = "jdguillot";
        userEmail = "jdguillot@outlook.com";
      };

      shell = {
        fish.enable = true;
        starship.enable = true;
      };

      editor = {
        vim.enable = true;
        neovim.enable = true;
      };

      terminal = {
        # Auto-enabled because host has desktop environment
        zellij.enable = true;
      };

      # Desktop features auto-enabled because host has desktop environment
      # No need to set desktop.enable = true
    };
  };

  programs.home-manager.enable = true;
}
```

**Note:** On this desktop host:
- `profile.enable` automatically inherits "desktop" from razer-nixos
- `features.desktop.enable` automatically set to `true`
- `features.terminal.enable` automatically set to `true`

### Work User (jdguillot on work-nix-wsl)

```nix
{
  imports = [
    ../modules
    ../features/cli/lazyvim/lazyvim.nix
    # ... other imports
  ];

  cyberfighter = {
    # Profile automatically inherits "wsl" from work-nix-wsl host
    # profile.enable is auto-set to "wsl"

    system = {
      username = "jdguillot";
      homeDirectory = "/home/jdguillot";
      stateVersion = "24.11";
    };

    packages = {
      includeDev = true;
      extraPackages = with pkgs; [
        avahi
        geckodriver
      ];
    };

    features = {
      # Git, shell, editor, and tools are enabled by default
      git = {
        userName = "jonathan-guillot_emcor";
        userEmail = "jonathan_guillot@emcor.net";
      };

      shell = {
        fish.enable = true;
        starship.enable = true;
      };

      desktop = {
        # Desktop features remain disabled on WSL unless explicitly enabled
        firefox.enable = true;  # Can still enable specific apps
      };
    };
  };
}
```

**Note:** On this WSL host:
- `profile.enable` automatically inherits "wsl" from work-nix-wsl
- `features.desktop.enable` stays `false` (no desktop environment on host)
- `features.terminal.enable` stays `false` (headless system)
- Individual desktop apps (like Firefox) can still be enabled manually

## Host Integration

Home-manager is integrated as a NixOS module, which means:

1. **Automatic Profile Inheritance**: The home-manager profile automatically matches the NixOS host profile
   - Desktop host → Desktop home-manager
   - WSL host → WSL home-manager
   - Minimal host → Minimal home-manager

2. **Desktop Auto-Detection**: Desktop and terminal features automatically enable when the host has a desktop environment

3. **Unified Deployment**: Running `nixos-rebuild switch` also activates home-manager configurations

**How it works:**
```nix
# In NixOS configuration
cyberfighter.profile.enable = "desktop";
cyberfighter.features.desktop.environment = "plasma6";

# In home-manager configuration
# Profile is automatically "desktop"
# Desktop features are automatically enabled
cyberfighter.features.desktop.enable;  # Auto-set to true
```

**Manual Override:**
If you need to override the automatic detection:
```nix
cyberfighter.profile.enable = lib.mkForce "minimal";
cyberfighter.features.desktop.enable = lib.mkForce false;
```

## Building and Switching

### Integrated (Recommended)

Since home-manager is integrated with NixOS, simply use:
```bash
sudo nixos-rebuild switch --flake .#hostname
# or use the alias
ns
```

This will build and activate both NixOS and home-manager configurations.

### Standalone (If Needed)

You can still build home-manager separately:
```bash
nix build .#homeConfigurations."user@host".activationPackage
home-manager switch --flake .#user@host
# or use the alias
hs
```

Available configurations:
- `cyberfighter@razer-nixos`
- `cyberfighter@sys-galp-nix`
- `cyberfighter@ryzn-nix-wsl`
- `jdguillot@work-nix-wsl`

## Mixing Modular and Legacy Configurations

The system allows mixing the new modular configuration with existing feature files from `home/features/`. This provides flexibility during migration:

```nix
{
  imports = [
    ../modules                              # New modular system
    ../features/cli/lazyvim/lazyvim.nix    # Legacy feature file
    ../features/desktop/alacritty/default.nix
  ];

  cyberfighter = {
    # New modular configuration
    features.git.enable = true;
  };
}
```

## Common Patterns

### Per-User Session Variables

```nix
home.sessionVariables = {
  GITHUB_USERNAME = "your-username";
  CUSTOM_VAR = "value";
};
```

### Per-User Files

```nix
home.file = {
  ".ssh/config".source = ../../secrets/.ssh_config_work;
  ".config/custom/config.yaml".text = ''
    key: value
  '';
};
```

### GPG and SSH Agent Setup

Already included in the default configuration:
```nix
services.gpg-agent = {
  enable = true;
  defaultCacheTtl = 600;
  maxCacheTtl = 3600;
  enableSshSupport = true;
};

programs.gpg.enable = true;
programs.gh = {
  enable = true;
  gitCredentialHelper.enable = true;
};
```

## Troubleshooting

### Unfree Packages

If you encounter unfree package errors, add to your configuration:
```nix
nixpkgs.config.allowUnfree = true;
```

### Package Conflicts

If you have package conflicts (e.g., Firefox being added twice):
- Remove the package from `extraPackages` if using a feature module
- Feature modules handle package installation automatically

### Path Issues

If imports fail:
- Ensure the module directory is tracked by git
- Use relative paths from the home.nix file location
- Check that `home/modules/default.nix` exists

## Migration Guide

To migrate a user from legacy to modular configuration:

1. Start with the basic module import:
   ```nix
   imports = [ ../modules ];
   ```

2. Set up core configuration:
   ```nix
   cyberfighter = {
     system.username = "user";
     system.homeDirectory = "/home/user";
     system.stateVersion = "24.11";
   };
   ```

3. Enable features incrementally:
   ```nix
   cyberfighter.features = {
     git.enable = true;
     shell.enable = true;
     # ... etc
   };
   ```

4. Keep legacy imports for complex configurations (LazyVim, Tmux, etc.) until fully migrated

5. Test the configuration:
   ```bash
   nix build .#homeConfigurations."user@host".activationPackage
   ```
