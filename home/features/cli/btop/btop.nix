{
  home.file = {
    ".config/btop/themes/nord-cold.theme".source = ./nord-cold.theme;
  };

  programs.btop = {
    enable = true;
    settings = {
      color_theme = "nord-cold";
    };
  };
}
