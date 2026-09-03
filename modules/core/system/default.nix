{
  config,
  lib,
  pkgs,
  hostMeta,
  ...
}:

let
  cfg = config.cyberfighter.system;
  inherit (config.cyberfighter) profile;
in
{
  # hostname/username/stateVersion default from the host's entry in
  # hosts/default.nix (same pattern as modules/core/traits); hosts only
  # set what deviates from their metadata.
  options.cyberfighter.system = {
    username = lib.mkOption {
      type = lib.types.str;
      default = hostMeta.system.username;
      defaultText = lib.literalExpression "hostMeta.system.username";
      description = "Primary username for the system";
    };

    userDescription = lib.mkOption {
      type = lib.types.str;
      default = cfg.username;
      description = "Full name of the primary user";
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      default = hostMeta.system.hostname;
      defaultText = lib.literalExpression "hostMeta.system.hostname";
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
      default = hostMeta.system.stateVersion;
      defaultText = lib.literalExpression "hostMeta.system.stateVersion";
      description = "NixOS state version";
    };

    bootloader = {
      type = lib.mkOption {
        type = lib.types.enum [
          "systemd-boot"
          "lanzaboote"
          "limine"
          "none"
        ];
        default = "none";
        description = ''
          Which bootloader to install. This is a single choice rather than a
          flag per loader because each of them defines
          `system.build.installBootLoader`, so enabling two is a conflict
          rather than a combination.

          - `systemd-boot`: the plain EFI stub loader.
          - `lanzaboote`: signed unified kernel images. Secure Boot is the
            entire point of it, so `secureBoot` is implied.
          - `limine`: themeable menu, chainloads other OSes across disks, and
            uses far less ESP space than unified kernel images. Boots fine
            unsigned; set `secureBoot` to sign it.
          - `none`: nothing is installed. Correct for WSL and containers,
            where NixOS does not own the boot process.
        '';
      };

      secureBoot = lib.mkOption {
        type = lib.types.bool;
        default = cfg.bootloader.type == "lanzaboote";
        defaultText = lib.literalExpression ''config.cyberfighter.system.bootloader.type == "lanzaboote"'';
        description = ''
          Sign the boot chain with the sbctl PKI in /var/lib/sbctl, so the
          firmware will load it with Secure Boot enabled.

          Run `sbctl create-keys` on the host before the first switch, and
          `sbctl enroll-keys --microsoft` before turning Secure Boot on --
          the Microsoft keys are what keep Windows bootable and let signed
          option ROMs (e.g. an NVIDIA GPU) initialise.
        '';
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
      # Shared by every real bootloader; skipped for "none" so WSL never
      # tries to write EFI variables it has no access to.
      (lib.mkIf (cfg.bootloader.type != "none") {
        loader.efi.canTouchEfiVariables = cfg.bootloader.efiCanTouchVariables;
      })

      (lib.mkIf (cfg.bootloader.type == "systemd-boot") {
        loader.systemd-boot.enable = true;
      })

      # Options live at boot.lanzaboote.*, NOT boot.loader.lanzaboote.*.
      (lib.mkIf (cfg.bootloader.type == "lanzaboote") {
        lanzaboote = {
          enable = true;
          # sbctl >= 0.14 keeps its PKI here; older guides still say
          # /etc/secureboot.
          pkiBundle = "/var/lib/sbctl";
          # Unbounded by default, and every generation is a full unified
          # kernel image on the ESP -- without a cap a 1G ESP fills up.
          configurationLimit = 10;
        };
        # The editor is an `init=/bin/sh` root shell the moment Secure Boot
        # is ever turned off; sd-stub only ignores the cmdline while it is on.
        loader.systemd-boot.editor = false;
      })

      (lib.mkIf (cfg.bootloader.type == "limine") {
        loader.limine = {
          enable = true;
          efiSupport = true;
          # Bound what the ESP holds (cheap: limine stores plain files, not
          # per-generation images).
          maxGenerations = 10;
          # `init=/bin/sh` at the menu, exploitable even with Secure Boot on
          # (no sd-stub equivalent); the module refuses secureBoot with it.
          enableEditor = false;
          # Signs the limine binary, hashes limine.conf into it, and turns on
          # fatal checksum validation for the kernel and initrd it loads.
          secureBoot.enable = cfg.bootloader.secureBoot;
        };
      })

      (lib.mkIf (cfg.bootloader.luksDevice != null) {
        initrd.luks.devices."luks-${cfg.bootloader.luksDevice}".device =
          "/dev/disk/by-uuid/${cfg.bootloader.luksDevice}";
      })
    ];

    environment.systemPackages = lib.mkIf (
      cfg.bootloader.type == "lanzaboote" || cfg.bootloader.type == "limine"
    ) [ pkgs.sbctl ];

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

    assertions =
      (lib.optionals (profile.enable != "wsl") [
        {
          assertion = cfg.wslOptions.windowsUsername == "cyberfighter";
          message = "wslOptions.windowsUsername can only be set when profile.enable is 'wsl'";
        }
      ])
      ++ [
        {
          assertion =
            cfg.bootloader.secureBoot
            -> (builtins.elem cfg.bootloader.type [
              "lanzaboote"
              "limine"
            ]);
          message = "cyberfighter.system.bootloader.secureBoot requires bootloader.type to be \"lanzaboote\" or \"limine\"; systemd-boot cannot sign its own boot chain.";
        }
        {
          assertion = (cfg.bootloader.type == "lanzaboote") -> cfg.bootloader.secureBoot;
          message = "cyberfighter.system.bootloader.type = \"lanzaboote\" always signs the boot chain; secureBoot cannot be disabled for it.";
        }
      ];
  };
}
