# Home Manager Modules - Complete Reference

This document provides complete documentation for all home-manager modules in this configuration.

## Table of Contents

- [Quick Start](#quick-start)
- [Overview](#overview)
- [Core Modules](#core-modules)
  - [Common Configuration](#cyberfightercommon)
  - [Profiles](#cyberfighterprofile)
  - [System Settings](#cyberfightersystem)
  - [User Groups](#cyberfighterusers)
  - [Packages](#cyberfighterpackages)
- [Feature Modules](#feature-modules)
  - [Git](#cyberfighterfeaturesgit)
  - [Shell](#cyberfighterfeaturesshell)
  - [Editor](#cyberfighterfeatureseditor)
  - [Terminal](#cyberfighterfeaturesterminal)
  - [Desktop](#cyberfighterfeaturesdesktop)
  - [Tools](#cyberfighterfeaturestools)
- [Host Integration](#host-integration)
- [Example Configurations](#example-configurations)
- [Advanced Topics](#advanced-topics)

## Quick Start

### Minimal Configuration

```nix
{
  imports = [ ../modules ];
  
  cyberfighter = {
    system = {
      username = "myuser";
      homeDirectory = "/home/myuser";
      stateVersion = "24.11";
    };
    
    features.git = {
      userName = "Your Name";
      userEmail = "your@email.com";
    };
  };
  
  programs.home-manager.enable = true;
}
```

### Desktop User Configuration

```nix
{
  imports = [ ../modules ];
  
  cyberfighter = {
    # Profile auto-inherits from system
    
    system = {
      username = "myuser";
      homeDirectory = "/home/myuser";
      stateVersion = "24.11";
    };
    
    packages.includeDev = true;
    
    features = {
      git = {
        userName = "Your Name";
        userEmail = "your@email.com";
      };
      
      shell = {
        fish.enable = true;
        starship.enable = true;
      };
      
      editor.neovim.enable = true;
      
      desktop = {
        firefox.enable = true;
        bitwarden.enable = true;
      };
      
      tools.enableDefault = true;
    };
  };
  
  programs.home-manager.enable = true;
}
```

## Overview

The home-manager configuration system provides modular user-level settings that:

- **Automatically inherit** profile settings from the NixOS host configuration
- **Enable by default** for common features (git, shell, editor, tools)
- **Auto-detect** desktop environments and enable appropriate features
- **Support** both modular and legacy feature configurations

### Module Organization

**Core Modules** (5):
- `common` - Base configuration (GPG, GitHub CLI, etc.)
- `profiles` - User profiles (desktop, minimal, wsl)
- `system` - User and home directory settings
- `users` - User group management
- `packages` - Package installation

**Feature Modules** (6):
- `git` - Git configuration
- `shell` - Shell configuration (Fish, Bash, Zsh, Starship)
- `editor` - Editor configuration (Vim, Neovim, VSCode)
- `terminal` - Terminal emulators and multiplexers
- `desktop` - Desktop applications
- `tools` - Development and utility tools

## Core Modules

### `cyberfighter.common`

Base configuration automatically enabled for all users.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `true` | Enable common configurations |

#### What's Configured

**Programs**:
- `home-manager` - Home Manager itself
- `bash` - Basic Bash configuration
- `gpg` - GnuPG
- `gh` - GitHub CLI with git credential helper

**Services**:
- `gpg-agent` - GPG agent with SSH support
  - Default cache TTL: 10 minutes
  - Max cache TTL: 1 hour
  - SSH support enabled

**Files**:
- `.markdownlint.yaml` - Markdown linting configuration

#### Examples

```nix
# Common is enabled by default
# No configuration needed

# Disable if needed (not recommended)
cyberfighter.common.enable = false;
```

#### Notes

- Always leave enabled unless you have specific requirements
- GPG agent handles both GPG and SSH keys
- GitHub CLI integration enables seamless git authentication

---

### `cyberfighter.profile`

User profile that determines default feature set.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | `"desktop"` \| `"minimal"` \| `"wsl"` | `"minimal"` | User profile |

#### Profile Behaviors

**Desktop Profile**:
- Auto-inherits from host if `osConfig.cyberfighter.features.desktop.enable = true`
- Auto-enables terminal and desktop features

**Minimal Profile**:
- CLI-only environment
- Desktop and terminal features disabled by default

**WSL Profile**:
- WSL-optimized configuration
- Graphics support for WSLg

#### Examples

```nix
# Auto-inherit from host (recommended)
# No configuration needed

# Manual override
cyberfighter.profile.enable = "minimal";
```

```nix
# Force desktop profile regardless of host
cyberfighter.profile.enable = lib.mkForce "desktop";
```

#### Notes

- Profile automatically inherits from NixOS host configuration
- Override only when needed with `lib.mkForce`
- Desktop features auto-enable when profile is "desktop"

---

### `cyberfighter.system`

User account and home directory settings.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `username` | string | `"cyberfighter"` | Username |
| `homeDirectory` | string | `/home/${username}` | Home directory path |
| `stateVersion` | string | `"24.11"` | Home Manager state version |

#### Examples

```nix
# Basic setup
cyberfighter.system = {
  username = "john";
  homeDirectory = "/home/john";
  stateVersion = "24.11";
};
```

```nix
# Custom home directory
cyberfighter.system = {
  username = "user";
  homeDirectory = "/data/home/user";
  stateVersion = "24.11";
};
```

```nix
# Different state version
cyberfighter.system = {
  username = "user";
  stateVersion = "25.05";
};
```

#### Notes

- `stateVersion` should match your first home-manager installation
- Don't change `stateVersion` on existing installations
- Home directory is automatically created if it doesn't exist

---

### `cyberfighter.users`

User group management (currently minimal functionality).

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `extraGroups` | list of string | `[]` | Additional groups (future use) |

#### Examples

```nix
# Currently not used
# System-level groups are set in NixOS configuration
```

#### Notes

- This module is a placeholder for future functionality
- Use NixOS `system.extraGroups` for actual group membership

---

### `cyberfighter.packages`

User-level package installation.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `includeDev` | bool | `false` | Include development packages |
| `extraPackages` | list of package | `[]` | Additional custom packages |

#### Package Sets

**Development Packages** (`includeDev = true`):
```nix
[
  python3
  gitmux
]
```

#### Examples

```nix
# No extra packages
cyberfighter.packages = { };
```

```nix
# Development packages
cyberfighter.packages.includeDev = true;
```

```nix
# Custom packages
cyberfighter.packages.extraPackages = with pkgs; [
  ripgrep
  fd
  bat
];
```

```nix
# Development + custom
cyberfighter.packages = {
  includeDev = true;
  extraPackages = with pkgs; [
    kubectl
    terraform
    awscli2
  ];
};
```

#### Notes

- Most CLI tools should be added via `features.tools` instead
- Use `extraPackages` for packages not in tool sets
- Development packages are minimal - add more as needed

---

## Feature Modules

### `cyberfighter.features.git`

Git configuration and settings.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `true` | Enable git configuration |
| `userName` | string | `"user"` | Git user name |
| `userEmail` | string | `"user@example.com"` | Git user email |
| `extraSettings` | attrs | `{}` | Additional git config settings |

#### Default Git Settings

```nix
{
  init.defaultBranch = "main";
  pull.rebase = true;
  diff.tool = "nvimdiff";
}
```

#### Examples

```nix
# Basic git configuration
cyberfighter.features.git = {
  userName = "John Doe";
  userEmail = "john@example.com";
};
```

```nix
# With custom settings
cyberfighter.features.git = {
  userName = "Jane Smith";
  userEmail = "jane@company.com";
  extraSettings = {
    core.editor = "vim";
    core.autocrlf = "input";
    push.default = "simple";
    merge.conflictstyle = "diff3";
  };
};
```

```nix
# Disable git configuration
cyberfighter.features.git.enable = false;
```

#### Notes

- Git credential helper is configured via `programs.gh`
- Diff tool uses neovim if available
- Pull rebase prevents merge commits on pull

---

### `cyberfighter.features.shell`

Shell configuration with multiple shell support and prompt customization.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `true` | Enable shell configuration |
| `fish.enable` | bool | `false` | Enable Fish shell |
| `fish.plugins` | list of attrs | `[]` | Fish plugins to install |
| `bash.enable` | bool | `false` | Enable Bash shell |
| `zsh.enable` | bool | `false` | Enable Zsh shell |
| `starship.enable` | bool | `false` | Enable Starship prompt |
| `extraSessionVariables` | attrs | `{}` | Additional session variables |
| `extraAliases` | attrs | `{}` | Additional shell aliases |

#### Default Session Variables

```nix
{
  EDITOR = "nvim";
  PIP_REQUIRE_VIRTUALENV = "true";
  FZF_DEFAULT_COMMAND = "fd --type f --strip-cwd-prefix";
}
```

#### Default Aliases

```nix
{
  # File listing
  ls = "eza --icons -F -H -g -h -o --group-directories-first --git -1 --tree --level=1 --ignore-glob='node_modules*'";
  ll = "ls -la";
  
  # Python virtual environments
  pysrc = ". .venv/bin/activate";
  pynew = "python -m venv .venv && pysrc && pip install -r requirements";
  
  # NixOS management
  ns = "sudo nixos-rebuild switch --flake ~/dotfiles && home-manager switch --flake ~/dotfiles";
  hs = "home-manager switch --flake ~/dotfiles";
  nu = "cd ~/dotfiles && nix flake update";
  nb = "sudo nixos-rebuild boot --flake ~/dotfiles && home-manager switch --flake ~/dotfiles";
  
  # Utilities
  myip = "curl -s ifconfig.me | grc curl -s \"https://ipapi.co/json/\$(cat)/json/\" | fx";
  dadjoke = "curl -H \"Accept: text/plain\" https://icanhazdadjoke.com/; echo";
  bwu = "export BW_SESSION=$(bw unlock --raw)";
}
```

#### Examples

```nix
# Fish shell with Starship
cyberfighter.features.shell = {
  fish.enable = true;
  starship.enable = true;
};
```

```nix
# Bash with custom aliases
cyberfighter.features.shell = {
  bash.enable = true;
  extraAliases = {
    vi = "nvim";
    lg = "lazygit";
  };
};
```

```nix
# Zsh with custom variables
cyberfighter.features.shell = {
  zsh.enable = true;
  starship.enable = true;
  extraSessionVariables = {
    TERM = "xterm-256color";
    LANG = "en_US.UTF-8";
  };
};
```

```nix
# Multiple shells
cyberfighter.features.shell = {
  fish.enable = true;
  bash.enable = true;
  zsh.enable = true;
  starship.enable = true;
};
```

```nix
# Fish with plugins
cyberfighter.features.shell = {
  fish.enable = true;
  fish.plugins = [
    {
      name = "z";
      src = pkgs.fetchFromGitHub {
        owner = "jethrokuan";
        repo = "z";
        rev = "ddeb28a7b6a1f0ec6dae40c636e5ca4908ad160a";
        sha256 = "0c5i7sdrsp0q3vbziqzdyqn4fmp235ax4mn4zslrswvn8g3fvdyh";
      };
    }
  ];
};
```

#### Notes

- Only one shell can be the default login shell
- Starship works with all supported shells
- Session variables apply to all shells
- Aliases are shared across enabled shells

---

### `cyberfighter.features.editor`

Editor configuration supporting multiple editors.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `true` | Enable editor configuration |
| `vim.enable` | bool | `false` | Enable Vim |
| `vim.plugins` | list of package | `[]` | Vim plugins |
| `neovim.enable` | bool | `false` | Enable Neovim |
| `vscode.enable` | bool | `false` | Enable VSCode configuration |
| `vscode.extensions` | list of string | `[]` | VSCode extensions |

#### Default Vim Plugins

When `vim.enable = true`:
```nix
[
  vimPlugins.vim-airline
  vimPlugins.vim-airline-themes
]
```

#### Examples

```nix
# Neovim only
cyberfighter.features.editor.neovim.enable = true;
```

```nix
# Vim with custom plugins
cyberfighter.features.editor = {
  vim.enable = true;
  vim.plugins = with pkgs.vimPlugins; [
    vim-airline
    nerdtree
    vim-fugitive
  ];
};
```

```nix
# VSCode with extensions
cyberfighter.features.editor = {
  vscode.enable = true;
  vscode.extensions = [
    "ms-python.python"
    "ms-vscode.cpptools"
    "vscodevim.vim"
  ];
};
```

```nix
# Multiple editors
cyberfighter.features.editor = {
  vim.enable = true;
  neovim.enable = true;
  vscode.enable = true;
};
```

```nix
# LazyVim configuration (import separately)
{
  imports = [
    ../modules
    ../features/cli/lazyvim/lazyvim.nix
  ];
  
  cyberfighter.features.editor.neovim.enable = true;
}
```

#### Notes

- For LazyVim: import `../features/cli/lazyvim/lazyvim.nix`
- VSCode extensions can also be managed via Settings Sync
- Multiple editors can coexist
- `EDITOR` environment variable defaults to `nvim`

---

### `cyberfighter.features.terminal`

Terminal emulator and multiplexer configuration.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | auto | Enable terminal features (auto on desktop) |
| `alacritty.enable` | bool | `false` | Enable Alacritty terminal |
| `ghostty.enable` | bool | `false` | Enable Ghostty terminal |
| `tmux.enable` | bool | `false` | Enable Tmux multiplexer |
| `zellij.enable` | bool | `false` | Enable Zellij multiplexer |
| `zellij.theme` | string | `"nord"` | Zellij theme |
| `zellij.font` | string | `"FiraCode Nerd Font"` | Zellij font |

#### Auto-Detection

Terminal features automatically enable when:
- Host has `osConfig.cyberfighter.features.desktop.enable = true`
- Profile is set to "desktop"

#### Examples

```nix
# Auto-enabled on desktop systems
# No configuration needed
```

```nix
# Alacritty terminal
cyberfighter.features.terminal.alacritty.enable = true;
```

```nix
# Ghostty terminal
cyberfighter.features.terminal.ghostty.enable = true;
```

```nix
# Tmux multiplexer
cyberfighter.features.terminal.tmux.enable = true;
```

```nix
# Zellij multiplexer
cyberfighter.features.terminal = {
  zellij.enable = true;
  zellij.theme = "catppuccin";
  zellij.font = "Hack Nerd Font";
};
```

```nix
# Multiple terminals
cyberfighter.features.terminal = {
  alacritty.enable = true;
  tmux.enable = true;
};
```

```nix
# Import full configurations
{
  imports = [
    ../modules
    ../features/cli/tmux/default.nix
    ../features/desktop/alacritty/default.nix
    ../features/desktop/ghostty/default.nix
  ];
}
```

#### Notes

- For full Alacritty config: import `../features/desktop/alacritty/default.nix`
- For full Ghostty config: import `../features/desktop/ghostty/default.nix`
- For full Tmux config: import `../features/cli/tmux/default.nix`
- Zellij is a modern Rust-based multiplexer alternative to Tmux

---

### `cyberfighter.features.desktop`

Desktop application configuration.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | auto | Enable desktop features (auto on desktop) |
| `firefox.enable` | bool | `false` | Enable Firefox browser |
| `firefox.package` | package | `pkgs.firefox` | Firefox package to use |
| `bitwarden.enable` | bool | `false` | Enable Bitwarden |
| `extraPackages` | list of package | `[]` | Additional desktop packages |

#### Default Desktop Packages

When `enable = true`:
```nix
[
  bottles            # Windows app compatibility
  super-productivity # Productivity tool
  vivaldi            # Web browser
  qbittorrent        # Torrent client
]
```

#### Auto-Detection

Desktop features automatically enable when:
- Host has `osConfig.cyberfighter.features.desktop.enable = true`
- Profile is set to "desktop"

#### Examples

```nix
# Auto-enabled on desktop systems
# No configuration needed
```

```nix
# Firefox and Bitwarden
cyberfighter.features.desktop = {
  firefox.enable = true;
  bitwarden.enable = true;
};
```

```nix
# Custom Firefox version
cyberfighter.features.desktop = {
  firefox = {
    enable = true;
    package = pkgs.firefox-esr;
  };
};
```

```nix
# With extra applications
cyberfighter.features.desktop = {
  firefox.enable = true;
  extraPackages = with pkgs; [
    thunderbird
    libreoffice
    gimp
    inkscape
  ];
};
```

```nix
# Disable desktop features on WSL
cyberfighter.features.desktop.enable = false;
```

```nix
# Import additional desktop configs
{
  imports = [
    ../modules
    ../features/desktop/bitwarden.nix
  ];
  
  cyberfighter.features.desktop.firefox.enable = true;
}
```

#### Notes

- Bitwarden can also import from `../features/desktop/bitwarden.nix`
- Default packages provide common desktop utilities
- Use Flatpak (NixOS module) for additional GUI apps

---

### `cyberfighter.features.tools`

Development and utility tools collection.

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `true` | Enable tools |
| `enableDefault` | bool | `true` | Include default tool set |
| `extraPackages` | list of package | `[]` | Additional tools |

#### Default Tool Set

When `enableDefault = true`:

**Editors**:
- `micro` - Modern terminal text editor
- `zed-editor` - Fast code editor

**File Management**:
- `eza` - Modern ls replacement
- `fd` - Modern find replacement
- `zip`, `unzip` - Archive utilities
- `mc` - Midnight Commander file manager
- `duf` - Disk usage utility
- `tree` - Directory tree viewer
- `yazi` - Terminal file manager
- `dua` - Disk usage analyzer
- `bat` - Cat with syntax highlighting

**Shell Utilities**:
- `tldr` - Simplified man pages
- `fzf` - Fuzzy finder
- `zoxide` - Smart cd command
- `cht-sh` - Cheat sheet tool
- `pay-respects` - Modern command error helper
- `lazyssh` - SSH connection manager

**Version Control**:
- `gh` - GitHub CLI
- `git-crypt` - Git encryption

**Security**:
- `ssh-agents` - SSH agent management
- `gnupg` - GPG encryption
- `pinentry-curses` - GPG PIN entry

**Network**:
- `dig` - DNS lookup tool

**Containers**:
- `distrobox` - Container environments
- `lazydocker` - Docker TUI

**Text Processing**:
- `jq` - JSON processor
- `fx` - JSON viewer
- `ripgrep` - Fast text search

**Media**:
- `xclip` - Clipboard utility

**System**:
- `neofetch` - System information

**Nix**:
- `nix-your-shell` - Shell integration

**Fun**:
- `cmatrix` - Matrix rain effect
- `cowsay` - ASCII cow messages
- `lolcat` - Rainbow text
- `fortune` - Random quotes
- `cbonsai` - Bonsai tree generator
- `fireplace` - Terminal fireplace
- `asciiquarium` - ASCII aquarium
- `pipes` - Animated pipes

**Development**:
- `powershell` - PowerShell Core
- `tree-sitter` - Parser generator

**API Tools**:
- `posting` - API testing tool

#### Examples

```nix
# Default tool set
cyberfighter.features.tools.enable = true;
```

```nix
# With additional tools
cyberfighter.features.tools = {
  enableDefault = true;
  extraPackages = with pkgs; [
    kubectl
    terraform
    ansible
    docker-compose
  ];
};
```

```nix
# Custom tools only (no defaults)
cyberfighter.features.tools = {
  enableDefault = false;
  extraPackages = with pkgs; [
    git
    vim
    htop
  ];
};
```

```nix
# Disable all tools
cyberfighter.features.tools.enable = false;
```

#### Tool Categories

**Essential CLI**: `eza`, `fd`, `ripgrep`, `bat`, `fzf`, `zoxide`
**Productivity**: `tldr`, `cht-sh`, `lazyssh`
**Development**: `lazydocker`, `tree-sitter`, `posting`
**File Management**: `yazi`, `mc`, `dua`, `duf`
**Fun**: `cmatrix`, `pipes`, `asciiquarium`, `cbonsai`

#### Notes

- Most tools have sensible defaults
- Tools integrate well with shell aliases
- `eza` replaces `ls` via alias
- `zoxide` learns your directory habits

---

## Host Integration

Home-manager configurations automatically integrate with NixOS host settings.

### Automatic Profile Inheritance

```nix
# In NixOS configuration (hosts/hostname/configuration.nix)
cyberfighter.profile.enable = "desktop";

# In home-manager configuration (home/username/home.nix)
# Profile automatically inherits "desktop"
# No explicit setting needed
```

### Automatic Feature Detection

```nix
# In NixOS configuration
cyberfighter.features.desktop = {
  enable = true;
  environment = "plasma6";
};

# In home-manager configuration
# Desktop and terminal features automatically enable
cyberfighter.features.desktop.enable;  # Auto: true
cyberfighter.features.terminal.enable; # Auto: true
```

### Manual Override

```nix
# Override automatic detection
cyberfighter.profile.enable = lib.mkForce "minimal";
cyberfighter.features.desktop.enable = lib.mkForce false;
```

### Building Integrated Configuration

```bash
# Build both NixOS and home-manager
sudo nixos-rebuild switch --flake .#hostname

# Or use alias
ns
```

---

## Example Configurations

### Example 1: Minimal CLI User

```nix
{
  imports = [ ../modules ];
  
  cyberfighter = {
    system = {
      username = "user";
      stateVersion = "24.11";
    };
    
    features = {
      git = {
        userName = "User Name";
        userEmail = "user@example.com";
      };
      
      shell.bash.enable = true;
      
      editor.vim.enable = true;
      
      tools.enableDefault = true;
    };
  };
  
  programs.home-manager.enable = true;
}
```

### Example 2: Full Desktop User

```nix
{
  imports = [
    ../modules
    ../features/cli/lazyvim/lazyvim.nix
    ../features/cli/tmux/default.nix
    ../features/desktop/alacritty/default.nix
  ];
  
  cyberfighter = {
    # Profile auto-inherits "desktop" from host
    
    system = {
      username = "john";
      stateVersion = "24.11";
    };
    
    packages.includeDev = true;
    
    features = {
      git = {
        userName = "John Doe";
        userEmail = "john@example.com";
      };
      
      shell = {
        fish.enable = true;
        starship.enable = true;
      };
      
      editor.neovim.enable = true;
      
      # Terminal auto-enabled
      
      desktop = {
        firefox.enable = true;
        bitwarden.enable = true;
        extraPackages = with pkgs; [
          thunderbird
          libreoffice
        ];
      };
      
      tools.enableDefault = true;
    };
  };
  
  programs.home-manager.enable = true;
}
```

### Example 3: Development User

```nix
{
  imports = [ ../modules ];
  
  cyberfighter = {
    system = {
      username = "dev";
      stateVersion = "24.11";
    };
    
    packages = {
      includeDev = true;
      extraPackages = with pkgs; [
        nodejs
        python3
        rustc
        cargo
      ];
    };
    
    features = {
      git = {
        userName = "Developer";
        userEmail = "dev@company.com";
        extraSettings = {
          core.editor = "nvim";
          diff.tool = "vimdiff";
        };
      };
      
      shell = {
        zsh.enable = true;
        starship.enable = true;
        extraAliases = {
          d = "docker";
          dc = "docker-compose";
          k = "kubectl";
        };
      };
      
      editor = {
        neovim.enable = true;
        vscode.enable = true;
      };
      
      tools = {
        enableDefault = true;
        extraPackages = with pkgs; [
          kubectl
          terraform
          ansible
          docker-compose
        ];
      };
    };
  };
  
  programs.home-manager.enable = true;
}
```

### Example 4: WSL User

```nix
{
  imports = [
    ../modules
    ../features/cli/lazyvim/lazyvim.nix
  ];
  
  cyberfighter = {
    # Profile auto-inherits "wsl" from host
    
    system = {
      username = "wsluser";
      stateVersion = "24.11";
    };
    
    packages = {
      includeDev = true;
      extraPackages = with pkgs; [
        awscli2
        azure-cli
      ];
    };
    
    features = {
      git = {
        userName = "WSL User";
        userEmail = "wsl@company.com";
      };
      
      shell = {
        fish.enable = true;
        starship.enable = true;
      };
      
      editor.neovim.enable = true;
      
      # Desktop features disabled on WSL
      desktop.enable = false;
      
      tools = {
        enableDefault = true;
        extraPackages = with pkgs; [
          kubectl
          terraform
        ];
      };
    };
  };
  
  programs.home-manager.enable = true;
}
```

### Example 5: Multiple Shell Setup

```nix
{
  imports = [ ../modules ];
  
  cyberfighter = {
    system = {
      username = "polyglot";
      stateVersion = "24.11";
    };
    
    features = {
      git = {
        userName = "Polyglot User";
        userEmail = "poly@example.com";
      };
      
      shell = {
        fish.enable = true;
        bash.enable = true;
        zsh.enable = true;
        starship.enable = true;
        
        extraSessionVariables = {
          TERM = "xterm-256color";
        };
        
        extraAliases = {
          vi = "nvim";
          vim = "nvim";
        };
      };
      
      editor.neovim.enable = true;
    };
  };
  
  # Set default shell (Fish in this case)
  programs.fish.enable = true;
  
  programs.home-manager.enable = true;
}
```

### Example 6: Minimal Server User

```nix
{
  imports = [ ../modules ];
  
  cyberfighter = {
    system = {
      username = "admin";
      stateVersion = "24.11";
    };
    
    packages.extraPackages = with pkgs; [
      htop
      tree
    ];
    
    features = {
      git = {
        userName = "Admin";
        userEmail = "admin@server.com";
      };
      
      shell.bash.enable = true;
      
      editor.vim.enable = true;
      
      tools = {
        enableDefault = false;
        extraPackages = with pkgs; [
          ripgrep
          fd
          bat
        ];
      };
    };
  };
  
  programs.home-manager.enable = true;
}
```

---

## Advanced Topics

### Custom Session Variables

```nix
home.sessionVariables = {
  CUSTOM_VAR = "value";
  PATH = "$HOME/.local/bin:$PATH";
};
```

### Custom Files

```nix
home.file = {
  ".ssh/config".source = ../../secrets/.ssh_config;
  ".config/custom/config.yaml".text = ''
    key: value
    another: setting
  '';
};
```

### XDG Directories

```nix
xdg = {
  enable = true;
  configHome = "${config.home.homeDirectory}/.config";
  dataHome = "${config.home.homeDirectory}/.local/share";
  cacheHome = "${config.home.homeDirectory}/.cache";
};
```

### Per-User Services

```nix
systemd.user.services.my-service = {
  Unit = {
    Description = "My custom service";
  };
  Service = {
    ExecStart = "${pkgs.my-package}/bin/my-command";
    Restart = "on-failure";
  };
  Install = {
    WantedBy = [ "default.target" ];
  };
};
```

### Mixing Module and Legacy Configs

```nix
{
  imports = [
    ../modules                              # New modular system
    ../features/cli/lazyvim/lazyvim.nix    # Legacy feature
    ../features/cli/btop/btop.nix          # Legacy feature
    ../features/desktop/alacritty/default.nix
  ];
  
  cyberfighter = {
    # New modular configuration
    features.git.enable = true;
  };
}
```

### Program-Specific Configuration

```nix
# Direct home-manager options still work
programs.git.extraConfig = {
  url."git@github.com:".insteadOf = "https://github.com/";
};

programs.ssh = {
  enable = true;
  matchBlocks = {
    "github.com" = {
      identityFile = "~/.ssh/github_key";
    };
  };
};
```

### Package Overlays

```nix
nixpkgs.overlays = [
  (self: super: {
    my-custom-package = super.my-package.overrideAttrs (old: {
      # Custom modifications
    });
  })
];
```

---

## Troubleshooting

### Issue: Profile Not Auto-Detecting

**Problem**: Desktop features not enabling on desktop host

**Solution**:
```nix
# Check host configuration has:
cyberfighter.features.desktop.enable = true;

# Or manually set profile:
cyberfighter.profile.enable = lib.mkForce "desktop";
```

### Issue: Package Conflicts

**Problem**: Package installed multiple times

**Solution**:
```nix
# Remove from extraPackages if using feature module
# Features handle packages automatically
```

### Issue: Shell Not Changing

**Problem**: New shell config not activating

**Solution**:
```bash
# Re-login or source shell
exec $SHELL

# Check shell is installed
chsh -l

# Change default shell
chsh -s $(which fish)
```

### Issue: Unfree Packages

**Problem**: Cannot install unfree packages

**Solution**:
```nix
nixpkgs.config.allowUnfree = true;
```

### Issue: Import Path Not Found

**Problem**: Cannot import feature files

**Solution**:
```bash
# Ensure files are tracked by git
git add -f home/features/

# Use correct relative path
imports = [ ../features/cli/lazyvim/lazyvim.nix ];
```

---

## Building and Testing

### Build Home Manager

```bash
# Build and activate
home-manager switch --flake .#user@host

# Or use alias
hs

# Build without activating
nix build .#homeConfigurations."user@host".activationPackage

# Check for errors
home-manager build --flake .#user@host
```

### Test Configuration

```bash
# Dry run
home-manager build --flake .#user@host

# Check what would change
home-manager switch --flake .#user@host --dry-run
```

### Available Configurations

- `cyberfighter@razer-nixos`
- `cyberfighter@sys-galp-nix`
- `cyberfighter@ryzn-nix-wsl`
- `jdguillot@work-nix-wsl`

---

## Additional Resources

- **[NixOS Modules Documentation](MODULES.md)** - System-level configurations
- **[SOPS Secrets Guide](SOPS-MIGRATION.md)** - Managing secrets
- **[Main README](../README.md)** - Installation guide
- **[Home Manager Manual](https://nix-community.github.io/home-manager/)** - Official documentation
