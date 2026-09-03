# Game server VM running on the thkpd-pve1 Proxmox hypervisor
# Hosts an Astroneer dedicated server via AstroTuxLauncher (Wine-based launcher)
{
  inputs,
  config,
  modulesPath,
  pkgs,
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
    };

    nix.trustedUsers = [
      "root"
      "cyberfighter"
    ];

    packages = {
      includeBase = true;
      extraPackages = with pkgs; [
        ludusavi
      ];
    };

    features = {
      ssh = {
        enable = true;
        passwordAuth = false;
        permitRootLogin = "no";
      };

      tailscale.enable = true;

      sops = {
        enable = true;
        defaultSopsFile = ../../secrets/secrets.yaml;
      };

      gameserver = {
        enable = true;
        ludusavi.enable = true;

        astroneer = {
          enable = true;
          serverName = "vm-gameserver-playit";
          maxPlayers = 8;
          autoSaveInterval = 900;
          openFirewall = true;
          gamePort = 10806;
          secrets = {
            publicIp = "playit-tunnel-ip";
            serverPassword = "astroneer-server-password";
          };
        };
      };
    };
  };

  services.playit = {
    enable = true;
    secretPath = config.sops.secrets."playit-agent-secret".path;
  };

  # Upstream services.playit takes a path, so this one secret stays
  # host-declared.
  sops.secrets."playit-agent-secret" = { };
}
