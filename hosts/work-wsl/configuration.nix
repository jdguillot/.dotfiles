{
  pkgs,
  hostProfile,
  hostMeta,
  ...
}@inputs:
{
  imports = [
    ../../modules
    inputs.inputs.nixos-wsl.nixosModules.default
    inputs.inputs.nix-index-database.nixosModules.nix-index
    inputs.inputs.vscode-server.nixosModules.default
    inputs.inputs.home-manager.nixosModules.home-manager
  ];

  cyberfighter = {
    profile.enable = hostProfile;

    system = hostMeta.system // {
      stateVersion = "25.05";
      extraGroups = [ "docker" ];
    };

    nix = {
      enableDevenv = true;
      trustedUsers = [ "root" "jdguillot" ];
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
      graphics = {
        enable = true;
        nvidia.enable = true;
      };

      flatpak = {
        enable = true;
        browsers = true;
        cad = true;
      };

      docker.enable = true;
      tailscale.enable = true;

      vscode.enable = true;
    };
  };

  services.vscode-server.enable = true;

  wsl = {
    enable = true;
    defaultUser = "jdguillot";
    docker-desktop.enable = true;
    useWindowsDriver = true;
    wslConf.automount.root = "/";
    wslConf.interop.appendWindowsPath = false;
  };

  home-manager.users.jdguillot = {
    home.stateVersion = "25.05";
    home.sessionPath = [
      "/c/Users/jguillot778e/AppData/Local/Programs/Microsoft VS Code/bin"
      "/c/Windows/System32"
    ];
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
