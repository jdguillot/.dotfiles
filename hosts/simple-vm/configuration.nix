# Template for a minimal server
{
  inputs,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    ../../modules
    inputs.nix-index-database.nixosModules.nix-index
    ./disk-config.nix
    (modulesPath + "/profiles/qemu-guest.nix")
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
