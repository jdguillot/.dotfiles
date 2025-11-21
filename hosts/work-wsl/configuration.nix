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
  ];

  cyberfighter = {
    profile.enable = hostProfile;

    system = hostMeta.system // {
      stateVersion = "25.05";
      extraGroups = [ "docker" ];
    };

    nix = {
      enableDevenv = true;
      trustedUsers = [
        "root"
        "jdguillot"
      ];
    };

    packages = {
      includeDev = true;
      extraPackages = with pkgs; [
        moonlight-qt
        nil
        zulu8
        gradle
        playwright-driver
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

  environment.variables = {
    JAVA_HOME = "${pkgs.zulu8}";
    WAYLAND_DISPLAY = "";
    PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
    PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
  };

  environment.sessionVariables = {
    # Puts gcc libraries in the library path for mkdocs-exporter
    LD_LIBRARY_PATH = [ "${pkgs.stdenv.cc.cc.lib}/lib" ];
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
