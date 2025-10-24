{ pkgs, ... }:
{
  imports = [
    ../common.nix
    # ../common-linux.nix
    ../../programs/vscode.nix
    ../../programs/alacritty.nix
    ../../programs/bitwarden.nix
  ];
  # home.username = "jdguillot";
  # home.homeDirectory = "/home/jdguillot";

  # services.emacs = {
  #   enable = true;
  #   package = pkgs.emacsSebastiant;
  # };

  home.file = {
    "generate_ssh_key.sh".source = ../../scripts/generate_ssh_key.sh;
  };

  home.packages = with pkgs; [

  ];

  home.sessionVariables = {
    ## Github
    GITHUB_USERNAME = "jdguillot";

  };

  programs.git.settings = {
    user = {
      name = "jdguillot";
      email = "jdguillot@outlook.com";
    };
  };

  # home.file.".xsessionrc".text = ''
  #   xset r rate 200 50
  #   '';
  # home.file.".background-image/nixos-wallpaper.png".source = ./nixos-wallpaper.png;
  # xdg.configFile."sway/config".source = ../../programs/sway/config;
  # xdg.configFile."waybar/config".source = ../../programs/waybar/config;
}
