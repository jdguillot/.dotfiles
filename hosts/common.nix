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
    file = {
      # # Building this configuration will create a copy of 'dotfiles/screenrc' in
      # # the Nix store. Activating the configuration will then make '~/.screenrc' a
      # # symlink to the Nix store copy.
      # ".screenrc".source = dotfiles/screenrc;
      # ".config/Code/User/settings.json".source = ../programs/vscode/vscode-settings.json;

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

    sessionVariables = {
      ## Editor
      EDITOR = "code --wait";

      ## Python
      PIP_REQUIRE_VIRTUALENV = "true";

      ## fzf
      FZF_DEFAULT_COMMAND="fd --type f --strip-cwd-prefix";
      # FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND";
    };

    shellAliases = {
      ## Overriding default operations
      ls = "eza --icons -F -H --group-directories-first --git -1  --tree --level=1 --ignore-glob='node_modules*'";
      ll = "ls -la";

      ## Command Presets
      pysrc = ". .venv/bin/activate.fish";
      pynew = "python3 -m venv .venv && pysrc && pip install -r requirements";
    };
  };

  programs = {

    # Let Home Manager install and manage itself.
    home-manager.enable = true;


    # nixpkgs.config.allowUnfree = true;
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

#    ## NeoVim
#    neovim = {
#      enable = true;
#      withPython3 = true;
#      plugins = with pkgs.vimPlugins; [
#        coc-nvim
#        coc-python
#        context-filetype
#        # nerdree
#        neo-tree-nvim
#        fugitive
#        # onedark-vim
#        vim-tmux-navigator
#      ];
#      extraConfig = ''
#        set relativenumber
#        set number
#        set tabstop=2
#        set expandtab
#        set shiftwidth=2
#        set softtabstop=2
#        set wrap
#        set linebreak
#        set list
#        set lcs+=space:·
#        syntax on
#        set ignorecase
#        set smartcase
#        set hlsearch
#        set autoindent
#        set clipboard=unnamedplus
#        nnoremap <C-s> <ESC>:w<CR>
#        nnoremap <C-e> :Neotree filesystem reveal<CR>
#        nnoremap <M-Up> :m -2<CR>
#        nnoremap <M-Down> :m +1<CR>
#        " Coc Nvim
#
#        inoremap <silent><expr> <TAB>
#             \ coc#pum#visible() ? coc#pum#next(1) :
#             \ CheckBackspace() ? "\<Tab>" :
#             \ coc#refresh()
#        inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"
#
#        " Use <c-space> to trigger completion
#        if has('nvim')
#          inoremap <silent><expr> <c-space> coc#refresh()
#        else
#          inoremap <silent><expr> <c-@> coc#refresh()
#        endif
#
#        function! CheckBackspace() abort
#          let col = col('.') - 1
#          return !col || getline('.')[col - 1]  =~# '\s'
#        endfunction
#
#        " Use <c-space> to trigger completion
#        if has('nvim')
#          inoremap <silent><expr> <c-space> coc#refresh()
#        else
#          inoremap <silent><expr> <c-@> coc#refresh()
#        endif
#      '';
#    };

    ## Tmux
    tmux = {
      enable = true;
      shell = "${pkgs.fish}/bin/fish";
      terminal = "tmux-256color";
      historyLimit = 100000;
      plugins = with pkgs;
        [
          # tmux-nvim
          # tmuxPlugins.tmux-thumbs
          # # TODO: why do I have to manually set this
          # {
          #   plugin = t-smart-manager;
          #   extraConfig = ''
          #     set -g @t-fzf-prompt '  '
          #     set -g @t-bind "T"
          #   '';
          # }
          # {
          #   plugin = tmux-super-fingers;
          #   extraConfig = "set -g @super-fingers-key f";
          # }
          # {
          #   plugin = tmux-browser;
          #   extraConfig = ''
          #     set -g @browser_close_on_deattach '1'
          #   '';
          # }

          # tmuxPlugins.sensible
          # # must be before continuum edits right status bar
          {
            plugin = tmuxPlugins.catppuccin;

            extraConfig = '' 
              set -g @catppuccin_window_left_separator ""
              set -g @catppuccin_window_right_separator " "
              set -g @catppuccin_window_middle_separator " █"
              set -g @catppuccin_window_number_position "right"

              set -g @catppuccin_window_default_fill "number"
              set -g @catppuccin_window_default_text "#W"

              set -g @catppuccin_window_current_fill "number"
              set -g @catppuccin_window_current_text "#W"

              set -g @catppuccin_status_modules_right "directory host gitmux"
              set -g @catppuccin_status_left_separator  " "
              set -g @catppuccin_status_right_separator ""
              set -g @catppuccin_status_fill "icon"
              set -g @catppuccin_status_connect_separator "no"

              set -g @catppuccin_directory_text "#{pane_current_path}"
              # set -g @catppuccin_flavour 'frappe'
              # set -g @catppuccin_window_tabs_enabled on
              # set -g @catppuccin_date_time "%H:%M"
              # set -g @catppuccin_status_modules_right "... gitmux ..."
            '';
          }
          {
            plugin = tmuxPlugins.vim-tmux-navigator;
          }
        ];
      extraConfig = ''
        set -g mouse
        # set-option -g default-shell /usr/bin/fish 
        unbind r
        bind r source-file ~/.config/tmux/tmux.conf
        set -g prefix C-d
      '';
    };

    zellij = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        theme = "nord";
        font = "FiraCode Nerd Font";
        keybinds = {
          normal = {};
          pane = {};
        };
        default_mode = "tmux";
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
