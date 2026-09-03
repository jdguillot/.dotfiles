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
    system = {
      bootloader = {
        type = "systemd-boot";
        efiCanTouchVariables = true;
      };

      extraGroups = [ "docker" ];
    };

    nix.trustedUsers = [
      "root"
      "cyberfighter"
    ];

    features = {
      ssh = {
        enable = true;
        passwordAuth = false; # Key-only authentication
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
