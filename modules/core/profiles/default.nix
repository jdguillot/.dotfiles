{
  config,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.profile;
in
{
  options.cyberfighter.profile = {
    enable = lib.mkOption {
      type = lib.types.enum [
        "desktop"
        "wsl"
        "minimal"
        "none"
      ];
      default = "none";
      description = "Predefined system profile that bundles common settings";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.enable == "desktop") {
      cyberfighter = {
        features = {
          desktop.enable = lib.mkDefault true;
          graphics.enable = lib.mkDefault true;
          sound.enable = lib.mkDefault true;
          printing.enable = lib.mkDefault false;
          networking.networkmanager = lib.mkDefault true;

          flatpak = {
            enable = lib.mkDefault true;
            extraPackages = lib.mkDefault [
              "com.github.tchx84.Flatseal"
              "org.libreoffice.LibreOffice"
              "org.videolan.VLC"
            ];
          };
        };

        packages = {
          includeBase = lib.mkDefault true;
          includeDesktop = lib.mkDefault true;
        };

        system = {
          bootloader.systemd-boot = lib.mkDefault true;
        };
      };
    })

    (lib.mkIf (cfg.enable == "wsl") {
      cyberfighter = {
        features = {
          graphics.enable = lib.mkDefault true;
          networking.networkmanager = lib.mkDefault false;
        };

        packages = {
          includeBase = lib.mkDefault true;
          includeDesktop = lib.mkDefault false;
        };

        system = {
          bootloader.systemd-boot = lib.mkDefault false;
        };
      };

      # Enable user lingering for systemd user services (required for sops-nix in WSL)
      systemd.user.services."enable-linger" = {
        description = "Enable lingering for primary user (ensures systemd user services work in WSL)";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${config.systemd.package}/bin/loginctl enable-linger ${config.cyberfighter.system.username}";
        };
      };

      # NOTE: user@1000.service failing on the first WSL start after Windows login
      # is a cross-distro cgroup collision (all WSL distros share one cgroup tree;
      # another systemd distro booting first claims user@1000's delegated cgroup,
      # so ours gets EBUSY). Not fixable from inside this distro — mitigated by
      # keeping other distros' systemd disabled until microsoft/WSL PR #40519
      # (per-distro cgroup isolation) ships in a WSL release. See
      # https://github.com/microsoft/WSL/issues/40593
    })

    (lib.mkIf (cfg.enable == "minimal") {
      cyberfighter = {
        features = {
          networking.networkmanager = lib.mkDefault true;
        };

        packages = {
          includeBase = lib.mkDefault true;
          includeDesktop = lib.mkDefault false;
        };

        system = {
          bootloader.systemd-boot = lib.mkDefault true;
        };

      };

      boot.loader.timeout = 1;
      systemd.targets = {
        sleep.enable = false;
        suspend.enable = false;
        hibernate.enable = false;
        hybrid-sleep.enable = false;
      };

    })
  ];
}
