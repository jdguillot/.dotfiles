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
      # "${(import ./nix/sources.nix).sops-nix}/modules/sops"
      ../../programs/pia/pia.nix
      ../../programs/firejail.nix
    ];

  nix.extraOptions = ''
    extra-substituters = https://devenv.cachix.org
    extra-trusted-public-keys = devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=
    trusted-users = root cyberfighter
    keep-outputs = true
    keep-derivations = true
  '';

  users.defaultUserShell = pkgs.zsh;
  
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age = {
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };
  };

  programs.zsh.enable = true;


  nixpkgs.config = {
    allowUnfree = true;
  };

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.luks.devices."luks-490adcca-e0d1-4876-a6c4-72a61b0652e7".device = "/dev/disk/by-uuid/490adcca-e0d1-4876-a6c4-72a61b0652e7";

  networking.hostName = "razer-nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

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

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
  # services.xserver.desktopManager.plasma5.enable = true;

  # Hyperland
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };
  # environment.systemPackages = [ pkgs.kitty ]; # Required for hyperland default

  virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = [ "user-with-access-to-virtualbox" ];
  virtualisation.virtualbox.host.enableExtensionPack = true;

  # Enable the GNOME Desktop Environment.
  # services.xserver.displayManager.gdm.enable = true;
  # services.xserver.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = false;

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
  enable = false;
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
    useDefaultShell = true;
    packages = with pkgs; [
    #  thunderbird

    ];
  };

  # Enable automatic login for the user.
 # services.displayManager.autoLogin.enable = true;
 # services.displayManager.autoLogin.user = "cyberfighter";

  # Install firefox.
  programs.firefox.enable = true;

  environment.systemPackages = with pkgs; [
    cifs-utils
    # appimage-run
    xclip
    inputs.nixos-conf-editor.packages.${system}.nixos-conf-editor
    grc  
    nodejs
    wineWowPackages.stable
    distrobox
    kitty
    dolphin
    wofi
    nvim-pkg
    age
    sops
  ];

  services.flatpak.enable = true;
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  system.stateVersion = "24.05"; # Did you read the comment?

  ###### Begin Nvidia
  # Enable OpenGL
  hardware.graphics = {
    enable = true;
  };

#  boot.blacklistedKernelModules = ["nouveau"];

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {

    # Modesetting is required.
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fai>
    # Enable this if you have graphical corruption issues or application crashe>
    # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ in>
    # of just the bare essentials.
#    powerManagement.enable = false;

    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
#    powerManagement.finegrained = false;

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
#    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # https://discourse.nixos.org/t/plasma-5-works-with-nvidia-but-sddm-fails/29655/10

  hardware.nvidia.prime = {
    sync.enable = true;
  # Make sure to use the correct Bus ID values for your system!
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:2:0:0";
    # amdgpuBusId = "PCI:54:0:0"; For AMD GPU
  };

#  boot.initrd.kernelModules = [ "nvidia" ];
#  boot.extraModulePackages = [ config.boot.kernelPackages.nvidia_x11 ];

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

  ## put smb-scecret in /etc
  environment.etc."nixos/smb-secrets".source = ../../secrets/smb-secrets;

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
