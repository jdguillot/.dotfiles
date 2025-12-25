{
  lib,
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
        extraPackages = [
          "md.obsidian.Obsidian"
        ];
      };

      docker.enable = true;
      tailscale.enable = true;

      vscode.enable = true;

      sops.enable = true;
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
  };

  environment.sessionVariables = {
    # Puts gcc libraries in the library path for mkdocs-exporter
    LD_LIBRARY_PATH = [
      "${pkgs.stdenv.cc.cc.lib}/lib"
      "${pkgs.glib.out}/lib"
    ];
  };
  sops.secrets.work-ca = {
    sopsFile = ./100-PKROOTCA290-CA.yaml;
  };
  security.pki.certificates = lib.mkIf (builtins.pathExists /run/secrets/work-ca) [
    (builtins.readFile /run/secrets/work-ca)
  ];

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
