# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

let
  # home-manager = builtins.fetchTarball {
  #   url = "https://github.com/nix-community/home-manager/archive/release-24.05.tar.gz";
  #   sha256 = "0c83di08nhkzq0cwc3v7aax3x8y5m7qahyzxppinzwxi3r8fnjq3";
  # };
in

{ config, pkgs, system, inputs, ... }:

{

  
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    #  (import "${home-manager}/nixos")
    ];

  nixpkgs.config = {
    allowUnfree = true;
#    packageOverrides = pkgs: {
#      unstable = import unstableTarball {
#        config = config.nixpkgs.config;
#      };
#    };
  };

  # home-manager.users.cyberfighter = {
  #   home.stateVersion = "24.05";
  #   nixpkgs.config.allowUnfree = true;
  #   programs.git = {
  #     enable = true;
  #     userName  = "Jonathan Guillot";
  #     userEmail = "cyberfighter@gmail.com";
  #   };
  #   programs.vscode = {
  #     enable = true;
  #     extensions = with pkgs.vscode-extensions; [
  #       bbenoist.nix
  #       ms-python.python
  #       ms-azuretools.vscode-docker
  #       ms-vscode-remote.remote-ssh
  #       ms-vscode-remote.remote-containers
  #       esbenp.prettier-vscode
  #       ritwickdey.liveserver
  #       eamodio.gitlens
  #       visualstudioexptteam.intellicode-api-usage-examples
  #       github.vscode-pull-request-github
  #       redhat.vscode-yaml
  #       yzhang.markdown-all-in-one
  #       mhutchie.git-graph
  #       zhuangtongfa.material-theme
  #     ]; 
  #   };
  # };


  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "razer-nixos"; # Define your hostname.
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

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
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

  services.openssh = {
  enable = true;
  ports = [ 22 ];
  settings = {
    PasswordAuthentication = true;
    AllowUsers = null; # Allows all users by default. Can be [ "user1" "user2" ]
    UseDns = true;
    X11Forwarding = false;
    PermitRootLogin = "prohibit-password"; # "yes", "without-password", "prohibit-password", "forced-commands-only", "no"
  };
};

  ## Tailscale
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.cyberfighter = {
    isNormalUser = true;
    description = "Jonathan Guillot";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    packages = with pkgs; [
    #  thunderbird
      bitwarden-desktop
      vivaldi
      eza
#      vim
      ssh-agents
      tldr
      bitwarden-cli
      fzf
      fd
#      zip
      git-crypt
      gnupg
      pinentry-curses
#      fish
      starship
#      chezmoi
      fira-code
      fira-code-symbols
      (nerdfonts.override { fonts = [ "FiraCode" ];})
      mc
      btop
#      avahi
#      firefox
#      geckodriver
      cmatrix
      gh
      neofetch
      distrobox
      jq
      qbittorrent-qt5 
    ];
  };

  # Install firefox.
  programs.firefox.enable = true;

  # Allow unfree packages
#  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget

  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
    cifs-utils
    appimage-run
    xclip
    zed-editor
    inputs.nixos-conf-editor.packages.${system}.nixos-conf-editor
#     fishPlugins.done
#     fishPlugins.fzf-fish
#     fishPlugins.forgit
# #    fishPlugins.hydro
#     fzf
#     fishPlugins.grc
    grc  
    nodejs
    wineWowPackages.stable
];

  services.flatpak.enable = true;
  # services.flatpak.packages = [
  #   # { appId = "com.brave.Browser"; origin = "flathub";  }
  #   "io.github.zen_browser.zen"
  #   "org.openscad.OpenSCAD"
  #   "org.freecadweb.FreeCAD"
  #   "com.usebottles.bottles"
  #   "org.libreoffice.LibreOffice"
  # ];

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
  system.stateVersion = "24.05"; # Did you read the comment?

  ###### Begin Nvidia
  # Enable OpenGL
  hardware.graphics = {
    enable = true;
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {

    # Modesetting is required.
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fai>
    # Enable this if you have graphical corruption issues or application crashe>
    # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ in>
    # of just the bare essentials.
    powerManagement.enable = false;

    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    powerManagement.finegrained = false;

    # Use the NVidia open source kernel module (not to be confused with the
    # independent third-party "nouveau" open source driver).
    # Support is limited to the Turing and later architectures. Full list of 
    # supported GPUs is at: 
    # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus 
    # Only available from driver 515.43.04+
    # Currently alpha-quality/buggy, so false is currently the recommended sett>
    open = false;

    # Enable the Nvidia settings menu,
        # accessible via `nvidia-settings`.
    nvidiaSettings = true;

    # Optionally, you may need to select the appropriate driver version for you>
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  hardware.nvidia.prime = {
  # Make sure to use the correct Bus ID values for your system!
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:2:0:0";
    # amdgpuBusId = "PCI:54:0:0"; For AMD GPU
  };

  ###### End Nvidia

  ###### Fish Shell
  programs.fish.enable = true;

  ###### Docker
  virtualisation.docker.enable = true;
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # home-manager.backupFileExtension = "backup";

  ## put smb-scecret in /etc
  environment.etc."nixos/smb-secrets".source = ./secrets/smb-secrets;

  # For mount.cifs, required unless domain name resolution is not needed.
  fileSystems = {
    "/mnt/truenas-home" = {
      device = "//truenas.cyberfighter.space/userdata/Jonny";
      fsType = "cifs";
      options = let
        # this line prevents hanging on network split
        automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";

      in ["${automount_opts},credentials=/etc/nixos/smb-secrets"];
    };
    "/mnt/truenas-scanner" = {
      device = "//truenas.cyberfighter.space/Shared/scanner";
      fsType = "cifs";
      options = let
        # this line prevents hanging on network split
        automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";

      in ["${automount_opts},credentials=/etc/nixos/smb-secrets"];
    };
    "/mnt/truenas-temp" = {
      device = "//truenas.cyberfighter.space/Shared/Temp";
      fsType = "cifs";
      options = let
        # this line prevents hanging on network split
        automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";

      in ["${automount_opts},credentials=/etc/nixos/smb-secrets"];
    };
  };
}
