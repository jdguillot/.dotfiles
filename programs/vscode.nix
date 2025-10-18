{ }:
{
  programs.vscode = {
    enable = true;
    profiles = {
      default = {
        userSettings = {
          "workbench.colorTheme" = "Best Themes - Nord Cold";
          "git.enableSmartCommit" = true;
          "editor.autoClosingQuotes" = "always";
          "editor.fontFamily" = "FiraCode Nerd Font Mono";
          "editor.fontLigatures" = true;
          "git.autofetch" = true;
        };
      };
    };
  };

  services.vscode-server.enable = true;
}

