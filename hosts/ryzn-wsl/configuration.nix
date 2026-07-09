{
  lib,
  pkgs,
  config,
  hostProfile,
  hostMeta,
  ...
}@inputs:
{
  imports = [
    ../../modules
    inputs.inputs.nixos-wsl.nixosModules.default
    inputs.inputs.nix-index-database.nixosModules.nix-index
  ];

  cyberfighter = {
    profile.enable = hostProfile;

    system = hostMeta.system // {
      extraGroups = [ "docker" ];
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
      ssh.enable = true;
      sops.enable = true;
      cachix.enable = true;
    };
  };

  wsl = {
    enable = true;
    defaultUser = "cyberfighter";
    useWindowsDriver = true;
    wslConf.automount.root = "/";
    wslConf.interop.enabled = true; # Ensure Windows interop is enabled
  };

  # Ensure binfmt_misc is properly set up for .exe files
  boot.binfmt.registrations = lib.mkIf config.wsl.enable {
    WSLInterop = {
      magicOrExtension = "MZ";
      interpreter = "/init";
      preserveArgvZero = false;
    };
  };

  environment.variables = {
    JAVA_HOME = "${pkgs.zulu8}";
    WAYLAND_DISPLAY = "";
  };

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
