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
- Follow existing module structure: global modules in `modules/global/`, optional in `modules/optional/`

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
- Feature modules: `home/features/cli/` or `home/features/desktop/`
- Secrets: encrypted in `secrets/` with git-crypt/sops
