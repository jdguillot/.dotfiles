{ pkgs, ... }:
{
  imports = [
    ../common.nix
    # ../common-linux.nix
    ../../programs/non-free.nix
  ];
  # home.username = "jdguillot";
  # home.homeDirectory = "/home/jdguillot";

  # services.emacs = {
  #   enable = true;
  #   package = pkgs.emacsSebastiant;
  # };

  home.packages = with pkgs; [
    avahi
    firefox
    geckodriver
  ];
  programs.firefox.package = pkgs.wrapFirefox pkgs.firefox-unwrapped {
      extraPolicies = {
      ExtensionSettings = {};
    };
  };

  home.sessionVariables = {
    ## Github
    GITHUB_USERNAME = "jonathan-guillot_emcor";

  };

  programs.git = {
      userName  = "jonathan-guillot_emcor";
      userEmail = "jonathan_guillot@emcor.net";
  };

  # home.file.".xsessionrc".text = ''
  #   xset r rate 200 50
  #   '';
  # home.file.".background-image/nixos-wallpaper.png".source = ./nixos-wallpaper.png;
  # xdg.configFile."sway/config".source = ../../programs/sway/config;
  # xdg.configFile."waybar/config".source = ../../programs/waybar/config;
}