{
  pkgs,
  inputs,
  ...
}:

let
  username = "jdguillot";
in
{
  imports = [
    # ./docker-desktop-fix.nix
    ../../modules/global/default.nix
    # ../../modules/optional/tailscale.nix
    ../../modules/optional/pkgs.nix
    # ../../modules/optional/docker.nix
    inputs.nixos-wsl.nixosModules.default
    inputs.nix-index-database.nixosModules.nix-index
    inputs.vscode-server.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
  ];

  cyberfighter.features = {
    graphics = {
      enable = true;
      nvidia = true;
    };
    flatpak = {
      enable = true;
      browsers = true;
      cad = true;
    };
    docker = {
      enable = true;
    };
    tailscale = {
      enable = true;
    };
  };

  wsl = {

    # WSL Options
    enable = true;
    defaultUser = "${username}";
    docker-desktop.enable = true;
    useWindowsDriver = true;
    wslConf.automount.root = "/";
    wslConf.interop.appendWindowsPath = false;
  };

  networking.hostName = "work-nix-wsl"; # Define your hostname.

  home-manager.users."${username}" = {
    home.stateVersion = "25.05";
    home.sessionPath = [
      "/c/Users/jguillot778e/AppData/Local/Programs/Microsoft VS Code/bin"
      "/c/Windows/System32"
    ];
  };

  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  nix.extraOptions = ''
    extra-substituters = https://devenv.cachix.org
    extra-trusted-public-keys = devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=
    trusted-users = root ${username}
    keep-outputs = true
    keep-derivations = true
  '';

  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  users.users."${username}" = {
    extraGroups = [
      "wheel"
      "docker"
    ];
  };

  environment.variables = {
    JAVA_HOME = "${pkgs.zulu8}";
    WAYLAND_DISPLAY = "";
  };

  security.pki.certificateFiles = [ ../../secrets/100-PKROOTCA290-CA.crt ];

  programs.nix-ld = {
    enable = true;
  };

  nixpkgs.config = {
    allowUnfree = true;
  };

  services.vscode-server.enable = true;

  environment.systemPackages = with pkgs; [
    moonlight-qt
    nil
    zulu8
    gradle
  ];

  xdg = {
    portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
      ];
      config.common.default = "*";
    };
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.stateVersion = "25.05"; # Did you read the comment?
}
