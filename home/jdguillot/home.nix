{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../common/default.nix
    ../features/cli/lazyvim/lazyvim.nix
    ../../programs/lazygit.nix
  ];

  home.username = lib.mkDefault "jdguillot";
  home.homeDirectory = lib.mkDefault "/home/${config.home.username}";

  home.packages = with pkgs; [
    avahi
    firefox
    geckodriver
  ];

  programs.firefox.package = pkgs.wrapFirefox pkgs.firefox-unwrapped {
    extraPolicies = {
      ExtensionSettings = { };
    };
  };

  home.sessionVariables = {
    ## Github
    GITHUB_USERNAME = "jonathan-guillot_emcor";

  };

  programs.git = {
    userName = "jonathan-guillot_emcor";
    userEmail = "jonathan_guillot@emcor.net";
  };

  home.file = {
    ".ssh/config".source = ../../secrets/.ssh_config_work;
    ".config/nix/nix.conf".source = ../../secrets/nix.conf;
  };

  home.stateVersion = "24.11";

}
