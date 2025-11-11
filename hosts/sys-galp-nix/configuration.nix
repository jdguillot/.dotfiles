# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, pkgs, ... }:

let
  username = "cyberfighter";
in
{
  imports = [
    # Include the results of the hardware scan.
    ../../modules/global/default.nix
    ../../modules/optional/pkgs.nix
    inputs.nix-index-database.nixosModules.nix-index

    ./hardware-configuration.nix
    ./flatpak.nix
  ];

  cyberfighter.features = {
    graphics = {
      enable = true;
    };
    flatpak = {
      enable = true;
      desktop = true;
    };
  };

  nix.extraOptions = ''
    extra-substituters = https://devenv.cachix.org
    extra-trusted-public-keys = devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=
    trusted-users = root ${username}
    keep-outputs = true
    keep-derivations = true
  '';

  users.defaultUserShell = pkgs.zsh;

  nixpkgs.config = {
    allowUnfree = true;
  };

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "sys-galp-nix"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  fonts.packages = with pkgs; [
    fira-code
    fira-mono
    nerd-fonts.fira-code
    nerd-fonts.fira-mono
  ];
  services = {

    # Enable the X11 windowing system.
    xserver.enable = true;

    # Enable the KDE Desktop Encironment
    displayManager.sddm.enable = true;
    desktopManager.plasma6.enable = true;

    # Enable the GNOME Desktop Environment.
    # services.xserver.displayManager.gdm.enable = true;
    # services.xserver.desktopManager.gnome.enable = true;

    # Configure keymap in X11
    xserver.xkb = {
      layout = "us";
      variant = "";
    };

    # Enable CUPS to print documents.
    printing.enable = true;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      # If you want to use JACK applications, uncomment this
      #jack.enable = true;

      # use the example session manager (no others are packaged yet so this is enabled by default,
      # no need to redefine it in your config for now)
      #media-session.enable = true;
    };
  };
  environment = {
    # List packages installed in system profile. To search, run:
    # $ nix search wget
    systemPackages = with pkgs; [
      #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
      #  wget
      cifs-utils
      xclip
      grc
      nodejs
      wineWowPackages.stable
      distrobox
      kitty
      wofi
      google-chrome
      #    zoom-us
      libreoffice
      htop
      neofetch
      bitwarden-desktop
      mangohud
      protonup-ng
      # konsole
      dig
      thunderbird
      cowsay
      lolcat
      fortune
      asciiquarium
    ];

    # environment.systemPackages = with pkgs; [
    #   waydroid
    # ];

    shellAliases = {
      dadjoke = "curl -s -H \"Accept: text/plain\" https://icanhazdadjoke.com | cowsay -f fox | lolcat";
    }; # powers up the default Bluetooth controller on boot

    sessionVariables = {
      STEAM_EXTRA_COMPAT_TOOLS_PATHS = "\${HOME}/.steam/root/compatibilitytools.d";
    };
  };
  hardware = {

    # Enable sound with pipewire.
    pulseaudio.enable = false;

    # hardware.graphics = {
    #   enable = true;
    #   enable32Bit = true;
    # };
    #
    # hardware.enableRedistributableFirmware = true;
    #
    bluetooth.enable = true; # enables support for Bluetooth
    bluetooth.powerOnBoot = true;
  };
  security.rtkit.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users = {
    ${username} = {
      isNormalUser = true;
      description = "Jonathan Guillot";
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
      packages = with pkgs; [
        kdePackages.kate
      ];
    };
    bella = {
      isNormalUser = true;
      description = "Bella Guillot";
    };
  };
  programs = {

    zsh.enable = true;

    # Install firefox.
    firefox.enable = true;

    bash.interactiveShellInit = ''
      curl -s -H \"Accept: text/plain\" https://icanhazdadjoke.com | cowsay -f fox | lolcat
    '';

    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      # dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
      localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
    };

    steam.gamescopeSession.enable = true;
    gamemode.enable = true;
  };

  virtualisation.waydroid.enable = true;

  # hardware.opengl has beed changed to hardware.graphics

  # services.xserver.videoDrivers = ["nvidia"];
  # services.xserver.videoDrivers = ["amdgpu"];

  # hardware.nvidia.modesetting.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  system.stateVersion = "24.11"; # Did you read the comment?

}
