{ config, lib, pkgs, ... }:

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

    # Common programs enabled for all users
    programs.home-manager.enable = true;
    programs.bash.enable = true;
    programs.gpg.enable = true;
    programs.gh = {
      enable = true;
      gitCredentialHelper.enable = true;
    };

    # Common services
    services.gpg-agent = {
      enable = true;
      defaultCacheTtl = 600;  # 10 minutes
      maxCacheTtl = 3600;  # 1 hour
      enableSshSupport = true;
      extraConfig = ''
        pinentry-program ${pkgs.pinentry-curses}/bin/pinentry-curses
      '';
    };

    # Common files
    home.file = {
      ".markdownlint.yaml".source = ../../../common/configs/.markdownlint.yaml;
    };
  };
}
