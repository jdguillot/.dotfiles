{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.system;
  inherit (config.cyberfighter) profile;
in
{
  options.cyberfighter.system = {
    username = lib.mkOption {
      type = lib.types.str;
      default = "cyberfighter";
      description = "Primary username for the system";
    };

    userDescription = lib.mkOption {
      type = lib.types.str;
      default = "Jonathan Guillot";
      description = "Full name of the primary user";
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      description = "System hostname";
    };

    timeZone = lib.mkOption {
      type = lib.types.str;
      default = "America/Los_Angeles";
      description = "System timezone";
    };

    locale = lib.mkOption {
      type = lib.types.str;
      default = "en_US.UTF-8";
      description = "System locale";
    };

    stateVersion = lib.mkOption {
      type = lib.types.str;
      default = "25.05";
      description = "NixOS state version";
    };

    bootloader = {
      systemd-boot = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable systemd-boot bootloader";
      };

      efiCanTouchVariables = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Allow bootloader to modify EFI variables";
      };

      luksDevice = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "LUKS device UUID for encrypted root";
      };
    };

    wslOptions = {
      windowsUsername = lib.mkOption {
        type = lib.types.str;
        default = "cyberfighter";
        description = "Username for the Windows user that will be utilizing WSL";
      };
    };

  };

  config = {
    networking.hostName = cfg.hostname;
    time.timeZone = cfg.timeZone;
    system.stateVersion = cfg.stateVersion;

    i18n.defaultLocale = cfg.locale;
    i18n.extraLocaleSettings = {
      LC_ADDRESS = cfg.locale;
      LC_IDENTIFICATION = cfg.locale;
      LC_MEASUREMENT = cfg.locale;
      LC_MONETARY = cfg.locale;
      LC_NAME = cfg.locale;
      LC_NUMERIC = cfg.locale;
      LC_PAPER = cfg.locale;
      LC_TELEPHONE = cfg.locale;
      LC_TIME = cfg.locale;
    };

    boot = lib.mkMerge [
      (lib.mkIf cfg.bootloader.systemd-boot {
        loader.systemd-boot.enable = true;
        loader.efi.canTouchEfiVariables = cfg.bootloader.efiCanTouchVariables;
      })

      (lib.mkIf (cfg.bootloader.luksDevice != null) {
        initrd.luks.devices."luks-${cfg.bootloader.luksDevice}".device =
          "/dev/disk/by-uuid/${cfg.bootloader.luksDevice}";
      })
    ];

    users.defaultUserShell = pkgs.zsh;
    programs.zsh.enable = true;

    users.users.${cfg.username} = {
      isNormalUser = true;
      description = cfg.userDescription;
      useDefaultShell = true;
    };

    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    nixpkgs.config.allowUnfree = true;

    assertions = lib.mkIf (profile.enable != "wsl") [
      {
        assertion = cfg.wslOptions.windowsUsername == "cyberfighter";
        message = "wslOptions.windowsUsername can only be set when profile.enable is 'wsl'";
      }
    ];
  };
}
