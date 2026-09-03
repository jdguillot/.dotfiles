# Template for a gaming desktop
{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    ../../modules
    inputs.nix-index-database.nixosModules.nix-index

    ./hardware-configuration.nix
  ];

  cyberfighter = {
    system = {
      userDescription = "Jonathan Guillot";

      bootloader = {
        type = "systemd-boot";
        efiCanTouchVariables = true;
      };
    };

    nix.trustedUsers = [
      "root"
      "cyberfighter"
    ];

    features = {
      desktop = {
        environment = "plasma6";
        firefox = true;
      };

      graphics = {
        enable = true;
        nvidia = {
          enable = true;
          # Configure for your GPU
          prime = {
            enable = false;
          };
        };
      };

      sound.enable = true;
      fonts.enable = true;
      bluetooth.enable = true;

      gaming.enable = true;

      flatpak.extraPackages = [
        "com.discordapp.Discord"
        "com.heroicgameslauncher.hgl"
      ];

      tailscale.enable = true;
    };
  };

  virtualisation.waydroid.enable = true; # For Android gaming
}
