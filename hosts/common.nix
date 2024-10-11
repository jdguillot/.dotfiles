{ pkgs, ... }:

{

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.


  imports = [
    ../programs/lazygit.nix
    ../programs/neovim.nix
    ../programs/zsh.nix
];


  home = {
    stateVersion = "24.05"; # Please read the comment before changing.

    # The home.packages option allows you to install Nix packages into your
    # environment.
    packages = with pkgs; [
      bottles
      micro
      super-productivity
      bitwarden-desktop
      vivaldi
      eza
      # vim
      ssh-agents
      tldr
      bitwarden-cli
      fzf
      fd
      zip
      git-crypt
      gnupg
      pinentry-curses
      # fish
      # starship
      # chezmoi
      fira-code
      fira-code-symbols
      (nerdfonts.override { fonts = [ "FiraCode" ];})
      mc
      btop
      cmatrix
      gh
      neofetch
      distrobox
      jq
      qbittorrent
      xclip
      zed-editor
      python3
      gitmux
      zoxide
      bat
      nixd
      ripgrep
      clang-tools
      gcc
      thefuck
    ];

    file = {
      # ".screenrc".source = dotfiles/screenrc;
      # ".config/Code/User/settings.json".source = ../programs/vscode/vscode-settings.json;

      # # You can also set the file content immediately.
      # ".gradle/gradle.properties".text = ''
      #   org.gradle.console=verbose
      #   org.gradle.daemon.idletimeout=3600000
      # '';
    };

    sessionVariables = {
      ## Editor
      EDITOR = "code --wait";

      ## Python
      PIP_REQUIRE_VIRTUALENV = "true";

      ## fzf
      FZF_DEFAULT_COMMAND="fd --type f --strip-cwd-prefix";
    };

    shellAliases = {
      ## Overriding default operations
      ls = "eza --icons -F -H --group-directories-first --git -1  --tree --level=1 --ignore-glob='node_modules*'";
      ll = "ls -la";

      ## Command Presets
      pysrc = ". .venv/bin/activate.fish";
      pynew = "python -m venv .venv && pysrc && pip install -r requirements";
    };
  };

  programs = {
    home-manager.enable = true;

    git = {
      enable = true;
      extraConfig = {
        init.defaultBranch = "main";
        pull.rebase = true;
        diff.tool = "nvimdiff";
      };
    };


    ### Bash Shell
    bash = {
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
    fish = {
      enable = true;
      interactiveShellInit = ''
        set fish_greeting # Disable greeting
      '';

      # Initialize Starship in Fish shell
      shellInit = ''
        eval (starship init fish)
        zoxide init fish | source
        fzf --fish | source
      '';
      plugins = [
        # Enable a plugin (here grc for colorized command output) from nixpkgs
        { name = "grc"; src = pkgs.fishPlugins.grc.src; }
        { name = "done"; src = pkgs.fishPlugins.done; }
        { name = "fzf-fish"; src = pkgs.fishPlugins.fzf-fish; }
        { name = "forgit"; src = pkgs.fishPlugins.forgit; }
      ];
    };

    starship = {
      enable = true;
      # Configuration written to ~/.config/starship.toml
      settings = (with builtins; fromTOML (readFile ../programs/starship/bracketed-segments.toml)) // {
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
    vim = {
      enable = true;
      plugins = with pkgs.vimPlugins; [ vim-airline ];
      settings = { ignorecase = true; };
      extraConfig = ''
        set mouse=a
        set cursorline
      '';
    };

    ## Tmux
    tmux = {
      enable = true;
      shell = "${pkgs.fish}/bin/fish";
      terminal = "tmux-256color";
      historyLimit = 100000;
      plugins = with pkgs;
        [
          {
            # plugin = tmuxPlugins.catppuccin;
            plugin = tmuxPlugins.nord;
            # extraConfig = '' 
              # set -g @catppuccin_window_left_separator ""
              # set -g @catppuccin_window_right_separator " "
              # set -g @catppuccin_window_middle_separator " █"
              # set -g @catppuccin_window_number_position "right"
              #
              # set -g @catppuccin_window_default_fill "number"
              # set -g @catppuccin_window_default_text "#W"
              #
              # set -g @catppuccin_window_current_fill "number"
              # set -g @catppuccin_window_current_text "#W"
              #
              # set -g @catppuccin_status_modules_right "directory host gitmux"
              # set -g @catppuccin_status_left_separator  " "
              # set -g @catppuccin_status_right_separator ""
              # set -g @catppuccin_status_fill "icon"
              # set -g @catppuccin_status_connect_separator "no"

              # set -g @catppuccin_directory_text "#{pane_current_path}"
            # '';
          }
        ];
      extraConfig = ''
        set -g mouse
        unbind r
        bind r source-file ~/.config/tmux/tmux.conf
        set -g prefix C-d
      '';
    };

    zellij = {
      enable = true;
      # enableFishIntegration = true;
      settings = {
        theme = "nord";
        font = "FiraCode Nerd Font";
        keybinds = {
          normal = {};
          pane = {};
        };
      };
    };

    # Enable GnuPG in Home Manager
    gpg = {
      enable = true;
    };
  };

  services = {
      
    # Configure gpg-agent
    gpg-agent = {
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
  };

}
