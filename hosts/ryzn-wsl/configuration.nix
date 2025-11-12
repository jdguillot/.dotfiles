{
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    ../../modules
    inputs.nixos-wsl.nixosModules.default
    inputs.nix-index-database.nixosModules.nix-index
  ];

  cyberfighter = {
    profile.enable = "wsl";

    system = {
      hostname = "ryzn-nix-wsl";
      username = "cyberfighter";
      userDescription = "Jonathan Guillot";
      stateVersion = "25.05";
      extraGroups = [ "docker" ];
    };

    nix = {
      enableDevenv = true;
      trustedUsers = [ "root" "cyberfighter" ];
    };

    packages = {
      includeDev = true;
      extraPackages = with pkgs; [
        moonlight-qt
        nil
        zulu8
        gradle
      ];
    };

    features = {
      graphics.enable = true;
      flatpak.enable = true;
      docker.enable = true;
    };
  };

  wsl = {
    enable = true;
    defaultUser = "cyberfighter";
    useWindowsDriver = true;
    wslConf.automount.root = "/";
  };

  environment.variables = {
    JAVA_HOME = "${pkgs.zulu8}";
    WAYLAND_DISPLAY = "";
  };

  security.pki.certificateFiles = [ ../../secrets/100-PKROOTCA290-CA.crt ];

  programs.nix-ld.enable = true;

  xdg = {
    portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
      ];
      config.common.default = "*";
    };
  };
}
