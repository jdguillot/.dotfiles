# Template for a gaming desktop
{
  inputs,
  pkgs,
  hostProfile,
  hostMeta,
  ...
}:
{
  imports = [
    ../../modules
    inputs.nix-index-database.nixosModules.nix-index

    ./hardware-configuration.nix
  ];

  cyberfighter = {
    profile.enable = hostProfile;

    system = {
      # Identity comes from the central metadata in hosts/default.nix.
      inherit (hostMeta.system) hostname username stateVersion;
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
