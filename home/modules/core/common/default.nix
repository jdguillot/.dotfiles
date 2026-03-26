{
  config,
  lib,
  pkgs,
  hostMeta,
  ...
}:

let
  cfg = config.cyberfighter.common;
in
{
  options.cyberfighter.common = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable common configurations for all users";
    };
  };

  config = lib.mkIf cfg.enable {
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
    };

    catppuccin = {
      enable = true;
      accent = "blue";
      flavor = "frappe";
    };
  };
}
