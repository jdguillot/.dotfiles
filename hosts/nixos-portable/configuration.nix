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
      };

      extraGroups = [
        "docker"
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
      extraPackages = with pkgs; [
        wget
        cifs-utils
        appimage-run
        xclip
        grc
        nodejs
        mangohud
        mangojuice
        moonlight-qt
        wakeonlan
      ];
    };

    features = {
      desktop = {
        environment = "plasma6";
      };

      graphics = {
        enable = true;
        nvidia = {
          enable = true;
          openDriver = true;
        };
      };

      sound.enable = true;
      fonts.enable = true;
      printing.enable = true;

      networking.networkmanager = true;

      gaming.enable = true;

      docker.enable = true;

      vpn.pia.enable = true;

      sops = {
        enable = true;
        defaultSopsFile = ../../secrets/secrets.yaml;
      };
    };
  };
}
