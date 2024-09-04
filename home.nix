{ config, pkgs, ... }:

{
  #  imports = [
  #   ./flatpak.nix
  # ];

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "cyberfighter";
  home.homeDirectory = "/home/cyberfighter";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "24.05"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;
    ".config/Code/User/settings.json".source = ./vscode-settings.json;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/cyberfighter/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    ## Github
    GITHUB_USERNAME = "jdguillot";

    ## Editor
    EDITOR = "code --wait";

    ## Python
    PIP_REQUIRE_VIRTUALENV = "true";

    ## fzf
    FZF_DEFAULT_COMMAND="fd --type f --strip-cwd-prefix";
    FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND";
  };

  home.shellAliases = {
    ## Overriding default operations
    ls = "eza --icons -F -H --group-directories-first --git -1  --tree --level=1 --ignore-glob='node_modules*'";
    ll = "ls -la";

    ## Command Presets
    pysrc = ". .venv/bin/activate.fish";
    pynew = "python3 -m venv .venv && pysrc && pip install -r requirements";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;


  nixpkgs.config.allowUnfree = true;
  programs.git = {
    enable = true;
    userName  = "jdguillot";
    userEmail = "cyberfighter@gmail.com";
    extraConfig = {
      init.defaultBranch = "main";
    };
  };
  programs.vscode = {
    enable = true;
    extensions = with pkgs.vscode-extensions; [
      bbenoist.nix
      ms-python.python
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
  };

  ### Bash Shell
  programs.bash = {
    enable = true;
    initExtra = ''
      if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
      then
        shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
        exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
      fi
    '';
  };

  ###### Fish Shell
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting # Disable greeting
    '';

    # Initialize Starship in Fish shell
    shellInit = ''
      eval (starship init fish)
    '';
    plugins = [
      # Enable a plugin (here grc for colorized command output) from nixpkgs
      { name = "grc"; src = pkgs.fishPlugins.grc.src; }
      { name = "done"; src = pkgs.fishPlugins.done; }
      { name = "fzf-fish"; src = pkgs.fishPlugins.fzf-fish; }
      { name = "forgit"; src = pkgs.fishPlugins.forgit; }
      # Manually packaging and enable a plugin
      # {
      #   name = "z";
      #   src = pkgs.fetchFromGitHub {
      #     owner = "jethrokuan";
      #     repo = "z";
      #     rev = "e0e1b9dfdba362f8ab1ae8c1afc7ccf62b89f7eb";
      #     sha256 = "0dbnir6jbwjpjalz14snzd3cgdysgcs3raznsijd6savad3qhijc";
      #   };
      # }
    ];
  };

  ## Alacritty
  programs.alacritty = {
    enable = true;
    settings = {
      window.opacity = 0.9;
      font.normal.family = "FiraCode Nerd Font Mono";
      selection.save_to_clipboard = true;
    };
  };

  programs.starship = {
  enable = true;
  # Configuration written to ~/.config/starship.toml
  settings = (with builtins; fromTOML (readFile ./starship/bracketed-segments.toml)) // {
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

  ## Vim Config
  programs.vim = {
    enable = true;
    plugins = with pkgs.vimPlugins; [ vim-airline ];
    settings = { ignorecase = true; };
    extraConfig = ''
      set mouse=a
      set cursorline
    '';
  };

  ## NeoVim
  programs.neovim = {
    enable = true;
    plugins = with pkgs.vimPlugins; [
      context-filetype
      # nerdree
      neo-tree-nvim
      fugitive
      onedark-vim
    ];
    extraConfig = ''
      colorscheme onedark
      set number
      set tabstop=2
      set expandtab
      set shiftwidth=2
      set softtabstop=2
      set wrap
      set linebreak
      set list
      set lcs+=space:·
      syntax on
      set ignorecase
      set smartcase
      set hlsearch
      set autoindent
      set clipboard=unnamedplus
      nnoremap <C-s> :w<CR>
      nnoremap <C-n> :Neotree filesystem reveal<CR>
      nnoremap <M-Up> :m -2<CR>
      nnoremap <M-Down> :m +1<CR>
    '';
  };

  ## Tmux
  programs.tmux = {
    enable = true;
    extraConfig = ''
      set -g mouse
      set-option -g default-shell /usr/bin/fish 
    '';
  };

  # Enable GnuPG in Home Manager
  programs.gpg = {
    enable = true;
  };
    
  # Configure gpg-agent
  services.gpg-agent = {
    enable = true;
    
    # Specify default caching time for the passphrase (in seconds)
    defaultCacheTtl = 600; # 10 minutes

    # Specify maximum caching time (in seconds)
    maxCacheTtl = 3600; # 1 hour

    # Automatically start gpg-agent
    enableSshSupport = true;

    # Additional custom options for gpg-agent
    extraConfig = ''
      # Example: Enable pinentry graphical dialog
      pinentry-program ${pkgs.pinentry}/bin/pinentry-gtk-2
    '';
  };

}
