# Game server VM running on the thkpd-pve1 Proxmox hypervisor (VM 101,
# 6 cores, 12G — raised from 8G on 2026-09-06 after the Astroneer server
# grew past it and the VM thrashed itself unreachable; the server's own
# ceiling is `gameserver.astroneer.memoryMax`).
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

  # Proxmox has `agent: 1` for this VM; without the guest service that
  # only means `qm agent ping` times out. With it, the hypervisor can
  # run diagnostics inside the guest when ssh cannot get in.
  services.qemuGuest.enable = true;

  # Upstream services.playit takes a path, so this one secret stays
  # host-declared.
  sops.secrets."playit-agent-secret" = { };
}
