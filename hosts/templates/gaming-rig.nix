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
    profile.enable = "desktop";

    system = {
      hostname = "gaming-rig";
      username = "gamer";
      userDescription = "Gamer Name";
      stateVersion = "25.05";

      bootloader = {
        systemd-boot = true;
        efiCanTouchVariables = true;
      };
    };

    nix.trustedUsers = [ "root" "gamer" ];

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
        "com.discord.Discord"
        "com.heroicgameslauncher.hgl"
      ];

      tailscale.enable = true;
    };
  };

  virtualisation.waydroid.enable = true;  # For Android gaming
}
