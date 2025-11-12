{
  pkgs,
  hostProfile,
  hostMeta,
  ...
}@inputs:
{
  imports = [
    ../../modules
    inputs.inputs.nix-index-database.nixosModules.nix-index
    ./hardware-configuration.nix
  ];

  cyberfighter = {

    profile.enable = hostProfile;

    system = hostMeta.system // {
      stateVersion = "24.11";

      bootloader = {
        systemd-boot = true;
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
      neofetch
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

      fonts.enable = true;
      printing.enable = true;

      bluetooth.enable = true;

      gaming.enable = true;

      flatpak.extraPackages = [
        "com.moonlight_stream.Moonlight"
        "io.github.flattool.Warehouse"
        "net.lutris.Lutris"
        "us.zoom.Zoom"
      ];
    };
  };

  users.users.bella = {
    isNormalUser = true;
    description = "Bella Guillot";
  };

  environment.shellAliases = {
    dadjoke = "curl -s -H \"Accept: text/plain\" https://icanhazdadjoke.com | cowsay -f fox | lolcat";
  };

  programs.bash.interactiveShellInit = ''
    curl -s -H \"Accept: text/plain\" https://icanhazdadjoke.com | cowsay -f fox | lolcat
  '';

  virtualisation.waydroid.enable = true;
}
