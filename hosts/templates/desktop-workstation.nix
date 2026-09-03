# Template for a full desktop workstation
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

      extraGroups = [ "docker" ];
    };

    nix = {
      enableDevenv = true;
      trustedUsers = [
        "root"
        "cyberfighter"
      ];
    };

    packages.extraPackages = with pkgs; [
      # Add host-specific packages here
    ];

    features = {
      desktop = {
        environment = "plasma6"; # or "gnome", "hyprland"
        firefox = true;
      };

      graphics.enable = true;

      fonts.enable = true;
      bluetooth.enable = true;

      flatpak.extraPackages = [
        # Add host-specific flatpaks
      ];

      docker.enable = true;
      tailscale.enable = true;

      sops = {
        enable = true;
        defaultSopsFile = ../../secrets/secrets.yaml;
      };
    };
  };
}
