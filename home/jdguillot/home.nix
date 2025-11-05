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
  ];
  home = {

    username = lib.mkDefault "jdguillot";
    homeDirectory = lib.mkDefault "/home/${config.home.username}";

    packages = with pkgs; [
      avahi
      firefox
      geckodriver
    ];

    sessionVariables = {
      ## Github
      GITHUB_USERNAME = "jonathan-guillot_emcor";

    };

    file = {
      ".ssh/config".source = ../../secrets/.ssh_config_work;
      ".config/nix/nix.conf".source = ../../secrets/nix.conf;
    };

    stateVersion = "24.11";
  };

  programs.firefox.package = pkgs.wrapFirefox pkgs.firefox-unwrapped {
    extraPolicies = {
      ExtensionSettings = { };
    };
  };

  programs.git.settings = {
    user = {
      name = "jonathan-guillot_emcor";
      email = "jonathan_guillot@emcor.net";
    };
  };

}
