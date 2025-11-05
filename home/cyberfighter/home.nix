{
  config,
  lib,
  ...
}:
let
  username = "cyberfighter";
in
{
  imports = [
    # ../../programs/vscode.nix
    ../common/default.nix
    ../features/cli/jujutsu.nix
  ];

  home = {

    username = lib.mkDefault "${username}";
    homeDirectory = lib.mkDefault "/home/${config.home.username}";

    sessionVariables = {
      ## Github
      GITHUB_USERNAME = "jdguillot";

    };

    file = {
      ".ssh/config".source = ../../secrets/.ssh_config_work;
      ".config/nix/nix.conf".source = ../../secrets/nix.conf;
    };

    stateVersion = "24.11";
  };

  programs.git.settings = {
    user = {
      name = "jdguillot";
      email = "jdguillot@outlook.com";
    };
  };

}
