# Template for a minimal server
{
  pkgs,
  hostProfile,
  hostMeta,
  modulesPath,
  ...
}@inputs:
{
  imports = [
    ../../modules
    inputs.inputs.nix-index-database.nixosModules.nix-index
    ./disk-config.nix
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  cyberfighter = {
    profile.enable = hostProfile;

    system = hostMeta.system // {
      stateVersion = "25.11";

      bootloader = {
        systemd-boot = true;
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
        passwordAuth = true; # Key-only authentication
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
