{
  pkgs,
  hostProfile,
  hostMeta,
  ...
}:
{
  imports = [
    ../modules
  ];

  cyberfighter = {
    profile.enable = hostProfile;

    system = {
      inherit (hostMeta.system) username stateVersion;
      homeDirectory = "/home/${hostMeta.system.username}";
    };

    features = {

      ssh = {
        enable = true;
      };

      shell = {
        starship.enable = true;
        zsh.enable = true;
      };

      editor = {
        vim.enable = true;
        neovim.enable = true;
        lazyvim.enable = true;
      };

      tools = {
        btop.enable = true;
        lazygit.enable = true;
        tmux.enable = true;
        yazi.enable = true;
        carapace.enable = true;
      };
    };
  };

}
