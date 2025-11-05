{
  home.file = {
    ".config/btop/themes/nord-cold.theme".source = ./nord-cold.theme;
    ".config/btop/themes/catppuccin_frappe.theme".source = ./catppuccin_frappe.theme;
  };

  programs.btop = {
    enable = true;
    settings = {
      color_theme = "catppuccin_frappe";
    };
  };
}
