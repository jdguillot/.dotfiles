# Template for a minimal server
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
    profile.enable = "minimal";

    system = {
      hostname = "my-server";
      username = "admin";
      userDescription = "System Administrator";
      stateVersion = "25.05";

      bootloader = {
        systemd-boot = true;
        efiCanTouchVariables = true;
      };

      extraGroups = [ "docker" ];
    };

    nix.trustedUsers = [ "root" "admin" ];

    features = {
      ssh = {
        enable = true;
        passwordAuth = false;  # Key-only authentication
        permitRootLogin = "no";
      };

      docker.enable = true;
      tailscale.enable = true;

      sops = {
        enable = true;
        defaultSopsFile = ../../secrets/secrets.yaml;
      };
    };
  };
}
