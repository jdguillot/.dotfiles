{
  config,
  lib,
  pkgs,
  hostProfile,
  hostMeta,
  ...
}:

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
    };

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
        ".markdownlint.yaml".source = ../../../common/configs/.markdownlint.yaml;
      };

      sessionPath = lib.mkIf (hostProfile == "wsl") [
        "/c/Users/${hostMeta.system.wslOptions.windowsUsername}/AppData/Local/Programs/Microsoft VS Code/bin"
        "/c/Windows/System32"
      ];
    };

  };
}
