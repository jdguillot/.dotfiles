{
  inputs,
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
        luksDevice = "490adcca-e0d1-4876-a6c4-72a61b0652e7";
      };

      extraGroups = [
        "docker"
        "dialout"
        "uucp"
      ];
    };

    nix = {
      enableDevenv = true;
      trustedUsers = [
        "root"
        "cyberfighter"
      ];
      # 8 cores / 15G RAM: parallel Rust derivations at `auto` page the
      # desktop out (idle sched only protects CPU/IO, not memory).
      maxJobs = 2;
      daemonMemoryHigh = "10G";

      # Offload heavy builds to ryzn-server (30G RAM) over Tailscale SSH --
      # tailnet ACLs are the auth, no key material; cyberfighter is already
      # in trusted-users there. Falls back to local when unreachable.
      remoteBuilders = [
        {
          hostName = "ryzn-server";
          sshUser = "cyberfighter";
          systems = [ "x86_64-linux" ];
          maxJobs = 2;
          speedFactor = 2;
          supportedFeatures = [
            "big-parallel"
            "kvm"
            "nixos-test"
          ];
        }
      ];
    };

    packages = {
      includeVirt = true;
      extraPackages = [
      ];
    };

    features = {
      desktop = {
        environment = "niri";
        displayManager = "greetd";
        firefox = true;
      };

      graphics = {
        nvidia = {
          enable = false;
          prime = {
            enable = true;
            intelBusId = "PCI:0:2:0";
            nvidiaBusId = "PCI:2:0:0";
          };
        };
      };

      fonts.enable = true;
      bluetooth.enable = true;

      # Opens 1714-1764 for the daemon that the cyberfighter home runs.
      kdeconnect.enable = true;
      printing.enable = true;

      onepassword.enable = true;
      wine.enable = true;

      gaming.enable = true;

      # IR camera is the greyscale node of the integrated 13d3:56d5 camera.
      gaze = {
        enable = true;
        gui = true;
        irCamera = "usb:13d3:56d5";
      };

      flatpak = {
        browsers = true;
        extraPackages = [
          "org.tigervnc.vncviewer"
          "org.rncbc.qsynth"
        ];
      };

      cachix.enable = true;

      docker.enable = true;
      tailscale = {
        enable = true;
        secrets.authKey = "tailscale-authkey";
      };

      security.firejail = true;

      vpn.pia.enable = true;

      sops = {
        enable = true;
        defaultSopsFile = ../../secrets/secrets.yaml;
      };
    };

    filesystems.truenas = {
      enable = true;
      mounts = {
        home = {
          share = "userdata/Jonny";
          mountPoint = "/mnt/truenas-home";
        };
        scanner = {
          share = "Shared/scanner";
          mountPoint = "/mnt/truenas-scanner";
        };
        temp = {
          share = "Shared/Temp";
          mountPoint = "/mnt/truenas-temp";
        };
      };
    };
  };

  # Compressed-RAM swap; outranks the disk partition (prio 5 vs -2), which
  # stays as overflow. Paging survives builds without going through the SSD.
  zramSwap.enable = true;

  # Tailscale SSH's per-node host key (port 22 on the tailnet address is
  # intercepted by tailscaled, not the real sshd). Pinned so the nix-daemon's
  # batch-mode SSH to the remote builder gets a known host; if it ever
  # rotates, builds fall back to local with a verification warning.
  programs.ssh.knownHosts."ryzn-server".publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILJF1qfm012fP6lTXrEA54zyK1+iYVEirdySFIe6L99l";

  programs.fish.enable = true;
  boot = {
    initrd = {
      systemd.enable = true;
      systemd.tpm2.enable = true;
      luks.devices."luks-be0e35d9-246c-4ac4-a166-f5fedaf87f29".crypttabExtraOpts = [
        "tpm2-device=auto"
        "tpm2-pcrs=7"
      ];
      luks.devices."luks-490adcca-e0d1-4876-a6c4-72a61b0652e7".crypttabExtraOpts = [
        "tpm2-device=auto"
        "tpm2-pcrs=7"
      ];
    };
  };
}
