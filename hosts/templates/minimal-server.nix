# Template for a minimal server
{
  pkgs,
  hostProfile,
  hostMeta,
  ...
}@inputs:
{
  imports = [
    ../../modules
    inputs.inputs.nix-index-database.nixosModules.nix-index
    ./hardware-configuration.nix
  ];

  cyberfighter = {
    profile.enable = hostProfile;

    system = {
      inherit (hostMeta.system) hostname username;

      stateVersion = "25.11";

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
