{
  programs.starship = {
    enable = true;
    # Configuration written to ~/.config/starship.toml
    settings = (with builtins; fromTOML (readFile ./starship.toml)) // {
      # overrides here, may be empty
    };
    #settings = {
    # add_newline = false;

    # character = {
    #   success_symbol = "[➜](bold green)";
    #   error_symbol = "[➜](bold red)";
    # };

    # package.disabled = true;
  };
}
