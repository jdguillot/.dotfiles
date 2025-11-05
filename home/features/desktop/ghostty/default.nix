{
  home.file = {
    ".config/ghostty/themes/catppuccin-frappe.conf".source = ./catppuccin-frappe.conf;
  };

  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      theme = "catppuccin-frappe.conf";
      fullscreen = "true";
      command = "tmux new-session -A -s new-session";
      confirm-close-surface = "false";
    };
  };
}
