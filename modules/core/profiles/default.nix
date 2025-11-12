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
    })
  ];
}
