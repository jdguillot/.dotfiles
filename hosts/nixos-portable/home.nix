{ pkgs, ... }:
{
  imports = [
    ../common.nix
    ../../programs/vscode.nix
    ../../programs/alacritty.nix
    ../../programs/bitwarden.nix
    ../../programs/lazyvim/lazyvim.nix
  ];

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
    GITHUB_USERNAME = "jdguillot";

  };

  programs.git = {
      userName  = "jdguillot";
      userEmail = "jdguillot@outlook.com";
  };

  home.file = {
      ".ssh/config".source = ../../secrets/.ssh_config_work;
      ".config/nix/nix.conf".source = ../../secrets/nix.conf;
    };

  # programs.vscode = {
  #   enable = true;
  #   enableExtensionUpdateCheck = true;
  #   enableUpdateCheck = true;
  #   extensions = with pkgs.vscode-extensions; [
  #     bbenoist.nix
  #     ms-python.python
  #     ms-azuretools.vscode-docker
  #     ms-vscode-remote.remote-ssh
  #     ms-vscode-remote.remote-containers
  #     esbenp.prettier-vscode
  #     ritwickdey.liveserver
  #     eamodio.gitlens
  #     visualstudioexptteam.intellicode-api-usage-examples
  #     github.vscode-pull-request-github
  #     redhat.vscode-yaml
  #     yzhang.markdown-all-in-one
  #     mhutchie.git-graph
  #     zhuangtongfa.material-theme
  #   ];
  # };


  

  # # Optionally, start the service automatically on home-manager switch
  # home.activation.install-vscode-extensions = lib.mkAfter ''
  #   systemctl --user start install-vscode-extensions.service
  # '';

  # home.file.".xsessionrc".text = ''
  #   xset r rate 200 50
  #   '';
  # home.file.".background-image/nixos-wallpaper.png".source = ./nixos-wallpaper.png;
  # xdg.configFile."sway/config".source = ../../programs/sway/config;
  # xdg.configFile."waybar/config".source = ../../programs/waybar/config;
}
