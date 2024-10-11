{

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    history = {
      size = 10000;
    };

    # Initialize Starship in Fish shell
    initExtra = ''
      eval "$(starship init zsh)"
      eval "$(zoxide init zsh)"
    '';

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "thefuck"
        "fzf"
      ];
    };
  };
}
