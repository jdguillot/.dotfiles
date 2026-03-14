{
  config,
  lib,
  pkgs,
  hostProfile,
  hostMeta,
  ...
}:

let
  isWsl = hostProfile == "wsl";

  # Derive Windows home from $USERPROFILE which WSL sets automatically
  wslPathsInit = ''
    if [ -n "$USERPROFILE" ]; then
      _win_home=$(wslpath "$USERPROFILE")
      export PATH="$_win_home/AppData/Local/Programs/Microsoft VS Code/bin:$_win_home/AppData/Local/Microsoft/WinGet/Packages/equalsraf.win32yank_Microsoft.Winget.Source_8wekyb3d8bbwe:$PATH"
    fi
  '';
in
{
  options.cyberfighter.common = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable common configurations for all users";
    };
  };

  config = lib.mkIf config.cyberfighter.common.enable {
    # Allow unfree packages
    nixpkgs.config.allowUnfree = true;
    programs = {

      # Common programs enabled for all users
      home-manager.enable = true;
      bash.enable = true;
      gpg.enable = true;
      gh = {
        enable = true;
        gitCredentialHelper.enable = true;
      };

      bash.initExtra = lib.mkIf isWsl wslPathsInit;
      zsh.initExtra = lib.mkIf isWsl wslPathsInit;
      fish.interactiveShellInit = lib.mkIf isWsl ''
        if set -q USERPROFILE
          set _win_home (wslpath "$USERPROFILE")
          fish_add_path "$_win_home/AppData/Local/Programs/Microsoft VS Code/bin"
          fish_add_path "$_win_home/AppData/Local/Microsoft/WinGet/Packages/equalsraf.win32yank_Microsoft.Winget.Source_8wekyb3d8bbwe"
        end
      '';
    };

    # Enable systemd user services (required for sops-nix home-manager module)
    systemd.user.enable = true;

    # Common services
    services.gpg-agent = {
      enable = true;
      defaultCacheTtl = 600; # 10 minutes
      maxCacheTtl = 3600; # 1 hour
      enableSshSupport = true;
      extraConfig = ''
        pinentry-program ${pkgs.pinentry-curses}/bin/pinentry-curses
      '';
    };

    home = {
      inherit (hostMeta.system) username;
      file = {
        ".markdownlint.yaml".source = ./.markdownlint.yaml;
        ".prettierrc".source = ./.prettierrc;
      };

      sessionPath = lib.mkIf isWsl [
        "/mnt/c/Windows/System32"
        "/mnt/c/Windows/System32/OpenSSH"
        "/mnt/c/Windows/System32/WindowsPowerShell/v1.0"
        "/mnt/c/Program Files/Docker/Docker/resources/bin"
      ];
    };

    catppuccin = {
      enable = true;
      accent = "blue";
      flavor = "frappe";
    };
  };
}
