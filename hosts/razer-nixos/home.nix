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

  ];

  home.sessionVariables = {
    ## Github
    GITHUB_USERNAME = "jdguillot";

  };

  programs.git = {
      userName  = "jdguillot";
      userEmail = "jdguillot@outlook.com";
  };

  programs.vscode = {
      enable = true;
      extensions = with pkgs.vscode-extensions; [
        bbenoist.nix
        ms-python.python
        ms-azuretools.vscode-docker
        ms-vscode-remote.remote-ssh
        ms-vscode-remote.remote-containers
        esbenp.prettier-vscode
        ritwickdey.liveserver
        eamodio.gitlens
        visualstudioexptteam.intellicode-api-usage-examples
        github.vscode-pull-request-github
        redhat.vscode-yaml
        yzhang.markdown-all-in-one
        mhutchie.git-graph
        zhuangtongfa.material-theme
      ]; 
    };

    ## Alacritty
  programs.alacritty = {
    enable = true;
    settings = {
      window.opacity = 0.9;
      font.normal.family = "FiraCode Nerd Font Mono";
      selection.save_to_clipboard = true;
    };
  };

  # home.file.".xsessionrc".text = ''
  #   xset r rate 200 50
  #   '';
  # home.file.".background-image/nixos-wallpaper.png".source = ./nixos-wallpaper.png;
  # xdg.configFile."sway/config".source = ../../programs/sway/config;
  # xdg.configFile."waybar/config".source = ../../programs/waybar/config;
}