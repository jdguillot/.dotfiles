{ pkgs, ... }:

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
    initContent = ''
      eval "$(starship init zsh)"
      eval "$(zoxide init zsh)"
      curl -s -H "Accept: text/plain" https://icanhazdadjoke.com | cowsay -f sus | lolcat

      if command -v nix-your-shell > /dev/null; then
        nix-your-shell zsh | source /dev/stdin
      fi
    '';

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        # "thefuck"
        "fzf"
        "gh"
      ];
    };
  };
}
