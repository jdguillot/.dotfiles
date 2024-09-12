{ config, pkgs, ... }:
{
  programs.vscode = {
    enable = true;
    extensions = with pkgs.vscode-extensions; [
      bbenoist.nix
      ms-python.python
      ms-python.vscode-pylance
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
    userSettings = {
      "workbench.colorTheme": "One Dark Pro Darker",
      "git.enableSmartCommit": true,
      "editor.autoClosingQuotes": "always",
      "editor.fontFamily": "FiraCode Nerd Font Mono",
      "editor.fontLigatures" = true;
      "git.autofetch": true
    };
  };
 }