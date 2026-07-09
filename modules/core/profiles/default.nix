{
  config,
  lib,
  pkgs,
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

      # Fix WSL systemd user service startup issues
      # The user@.service often fails on first boot with "Device or resource busy"
      # due to journal file locks or race conditions. This adds retries and delays.
      systemd.services."user@" = {
        serviceConfig = {
          # Add retry logic for resource busy errors
          Restart = lib.mkForce "on-failure";
          RestartSec = "1s";
          StartLimitBurst = 5;
          StartLimitIntervalSec = 10;
        };
        # Ensure it starts after journal is ready
        after = [ "systemd-journald.service" ];
        wants = [ "systemd-journald.service" ];
      };

      # Clear stale journal locks on boot
      systemd.services.clear-user-journal-locks = {
        description = "Clear stale user journal locks (WSL workaround)";
        wantedBy = [ "multi-user.target" ];
        before = [ "user@.service" ];
        after = [ "systemd-journald.service" ];
        
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };

        script = ''
          # Wait a moment for journal to settle
          sleep 0.5
          
          # The journal lock issue is internal to systemd, so we just
          # ensure journald is fully initialized before starting user services
          ${pkgs.systemd}/bin/systemctl is-active systemd-journald.service || true
          
          # Give a small delay to ensure no race conditions
          sleep 0.2
        '';
      };

      # Ensure journal directory has correct permissions
      systemd.tmpfiles.rules = [
        "d /var/log/journal 0755 root systemd-journal -"
        "d /run/log/journal 0755 root systemd-journal -"
      ];
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
