# Agent Instructions for NixOS Dotfiles

## Build/Test Commands

- Build NixOS config only: `sudo nixos-rebuild switch --flake .#<hostname>` (hostnames: razer-nixos, sys-galp-nix, work-nix-wsl, ryzn-nix-wsl, nixos-portable)
- Build home-manager only: `home-manager switch --flake .#<user>@<host>` (e.g., cyberfighter@razer-nixos, jdguillot@work-nix-wsl)
- Build both (via alias): `ns` (runs both nixos-rebuild and home-manager switch)
- Quick home-manager switch: `hs` (switches home-manager for current user@host)
- Test config without activation: `sudo nixos-rebuild test --flake .#<hostname>`
- Update flake inputs: `nu` (nix flake update)
- Check flake: `nix flake show`
- No traditional test suite exists

## Code Style

### Nix Files

- Use 2-space indentation, NO tabs
- **CRITICAL**: Always use Unix LF line endings (never CRLF/Windows line endings)
- Function signatures: parameters on separate lines with closing brace on its own line
- Imports at top, alphabetically ordered where reasonable
- Use `with pkgs;` for package lists
- Use `lib.mkDefault` and `lib.mkEnableOption` for options
- Follow existing module structure: core modules in `modules/core/`, feature modules in `modules/features/`

### Lua (LazyVim configs)

- 2-space indentation
- Minimal comments (see `keymaps.lua` example)

### Shell Scripts

- Use `#!/run/current-system/sw/bin/bash` shebang
- 2-space or 4-space indentation (match existing files)
- Quote variables: `"$VARIABLE"`
- Use `[[ ]]` for conditionals

## File Organization

- Host configs: `hosts/<hostname>/configuration.nix`
- Home configs: `home/<username>/home.nix`
- System modules: `modules/core/` (essential) and `modules/features/` (optional)
- Home feature modules: `home/features/cli/` or `home/features/desktop/`
- Secrets: encrypted in `secrets/` with git-crypt/sops

## Configuration Structure

### CRITICAL: Proper Attribute Nesting

When writing host configurations, **ALWAYS** properly nest attributes within the `cyberfighter` namespace. DO NOT flatten the structure.

**CORRECT** ✅:
```nix
{
  cyberfighter = {
    profile.enable = "desktop";
    
    system = {
      hostname = "my-nixos";
      username = "myuser";
      extraGroups = [ "docker" ];
    };
    
    nix = {
      enableDevenv = true;
      trustedUsers = [ "root" "myuser" ];
    };
    
    packages = {
      includeDev = true;
      extraPackages = with pkgs; [ htop ];
    };
    
    features = {
      desktop = {
        environment = "plasma6";
        firefox = true;
      };
      
      graphics = {
        enable = true;
        nvidia = {
          enable = true;
          prime = {
            enable = true;
            intelBusId = "PCI:0:2:0";
            nvidiaBusId = "PCI:2:0:0";
          };
        };
      };
      
      flatpak.extraPackages = [ "com.spotify.Client" ];
      
      docker.enable = true;
    };
  };
}
```

**INCORRECT** ❌:
```nix
{
  # DO NOT DO THIS - attributes are flattened
  cyberfighter.profile.enable = "desktop";
  cyberfighter.system.hostname = "my-nixos";
  cyberfighter.nix.enableDevenv = true;
  cyberfighter.packages.includeDev = true;
  cyberfighter.features.desktop.environment = "plasma6";
}
```

### Module Organization

Modules are organized into two categories:

1. **Core Modules** (`modules/core/`):
   - profiles (desktop, wsl, minimal)
   - system (hostname, user, bootloader)
   - users (group management)
   - nix-settings (Nix configuration)

2. **Feature Modules** (`modules/features/`):
   - desktop, sound, fonts, networking, printing
   - ssh, sops, graphics, docker, tailscale
   - flatpak, packages, filesystems, bluetooth, gaming
