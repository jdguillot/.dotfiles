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
  };

  security.pki.certificateFiles = [ ../../secrets/100-PKROOTCA290-CA.crt ];

  programs.nix-ld = {
    enable = true;
    package = pkgs.nix-ld-rs;
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
