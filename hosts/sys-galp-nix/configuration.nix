{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    ../../modules
    inputs.nix-index-database.nixosModules.nix-index
    ./hardware-configuration.nix
  ];

  cyberfighter = {

    system = {
      bootloader = {
        type = "systemd-boot";
        efiCanTouchVariables = true;
      };
    };

    nix = {
      enableDevenv = true;
      trustedUsers = [
        "root"
        "cyberfighter"
      ];
    };

    packages.extraPackages = with pkgs; [
      google-chrome
      htop
      fastfetch
      mangohud
      protonup-ng
      dig
      thunderbird
      cowsay
      lolcat
      fortune
      asciiquarium
    ];

    features = {
      desktop = {
        environment = "plasma6";
        firefox = true;
      };

      ssh.enable = true;
      fonts.enable = true;
      printing.enable = true;

      bluetooth.enable = true;

      # Opens 1714-1764 for the daemon that the cyberfighter home runs.
      kdeconnect.enable = true;

      gaming.enable = true;

      flatpak = {
        # bella is deliberately not in wheel, and her Plasma session runs
        # Discover's unattended updater against the system installation.
        unprivilegedRuntimeInstall = true;

        extraPackages = [
          "com.github.xournalpp.xournalpp"
          "us.zoom.Zoom"
        ];
      };

      sops = {
        enable = true;
        defaultSopsFile = ../../secrets/secrets.yaml;
        deployUserAgeKey = true;
      };

    };
  };

  users.users.bella = {
    isNormalUser = true;
    description = "Bella Guillot";
  };

  environment.shellAliases = {
    dadjoke = "curl -s -H \"Accept: text/plain\" https://icanhazdadjoke.com | cowsay -f sus | lolcat";
  };

  programs.bash.interactiveShellInit = ''
    curl -s -H \"Accept: text/plain\" https://icanhazdadjoke.com | cowsay -f sus | lolcat
  '';

  virtualisation.waydroid.enable = true;
}
