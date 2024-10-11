{ pkgs, ... }:

{

  # home.packages = with pkgs; [
  #   oh-my-zsh
  #   # zsh
  #   zsh-completions
  #   zsh-autosuggestions
  #   thefuck
  #   zsh-syntax-highlighting
  #   zsh-fast-syntax-highlighting
  #   zsh-autocomplete
  # ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    # autosuggestions.enable = true;
    syntaxHighlighting.enable = true;

    history = {
      size = 10000;
    };

    # Initialize Starship in Fish shell
    initExtra = ''
      eval "$(starship init zsh)"
      eval "$(zoxide init zsh)"
      fzf --zsh | source
    '';

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "thefuck"
        "zsh-autosuggestions"
        "zsh-syntax-highlighting"
        "fast-syntax-highlighting"
        "zsh-autocomplete"
      ];
    };
  };
}
