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

    system = hostMeta.system // {
      stateVersion = "25.05";

      bootloader = {
        systemd-boot = true;
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
    };

    packages = {
      includeDev = true;
      extraPackages = [
        inputs.inputs.nixos-conf-editor.packages.${pkgs.stdenv.hostPlatform.system}.nixos-conf-editor
      ];
    };

    features = {
      desktop = {
        environment = "plasma6";
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

      wine.enable = true;

      gaming.enable = true;

      flatpak = {
        browsers = true;
        extraPackages = [
          "org.rncbc.qsynth"
        ];
      };

      docker.enable = true;
      tailscale.enable = true;

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

  programs.fish.enable = true;
}
