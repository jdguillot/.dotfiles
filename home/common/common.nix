{
  pkgs,
  pkgs-temp,
  inputs,
  ...
}:

{

  home = {
    stateVersion = "24.11"; # Please read the comment before changing.

    # The home.packages option allows you to install Nix packages into your
    # environment.
    packages =
      with pkgs;
      [
        bottles
        micro
        super-productivity
        # bitwarden-desktop
        vivaldi
        eza
        # vim
        ssh-agents
        tldr
        # bitwarden-cli
        fzf
        fd
        zip
        unzip
        git-crypt
        gnupg
        pinentry-curses
        # fish
        # starship
        # chezmoi
        fira-code
        fira-code-symbols
        nerd-fonts.fira-code
        mc
        # btop
        cmatrix
        gh
        neofetch
        distrobox
        jq
        qbittorrent
        xclip
        zed-editor
        python3
        # gitmux
        zoxide
        bat
        nixd
        ripgrep
        duf
        cht-sh
        clang-tools
        gcc
        pay-respects
        devenv
        nix-your-shell
        dua
        lazyssh
        inputs.isd.packages.${system}.default
        lazydocker
        dig
        cowsay
        lolcat
        fortune
        cbonsai
        fireplace
        asciiquarium
        pipes
        tree
        fx
        powershell
        tree-sitter
      ]
      ++ [
        pkgs-temp.gitmux
        pkgs-temp.bitwarden-desktop
      ];

    # fonts.packages = [
    #   pkgs.fira-code
    #   pkgs.fira-code-symbols
    # ];

    file = {

    };

    sessionVariables = {
      ## Editor
      EDITOR = "nvim";

      ## Python
      PIP_REQUIRE_VIRTUALENV = "true";

      ## fzf
      FZF_DEFAULT_COMMAND = "fd --type f --strip-cwd-prefix";
    };

    shellAliases = {
      ## Overriding default operations
      ls = "eza --icons -F -H -g -h -o --group-directories-first --git -1  --tree --level=1 --ignore-glob='node_modules*'";
      ll = "ls -la";

      ## Command Presets
      pysrc = ". .venv/bin/activate";
      pynew = "python -m venv .venv && pysrc && pip install -r requirements";

      nswitch = "sudo nixos-rebuild switch --flake ~/.dotfiles";
      nupdate = "nix flake update --flake ~/.dotfiles";
      nboot = "sudo nixos-rebuild boot --flake ~/.dotfiles";

      myip = "curl http://ip-api.com/json/ -s | jq";

      dadjoke = "curl -s -H \"Accept: text/plain\" https://icanhazdadjoke.com | cowsay -f sus | lolcat";

      bwu = "export BW_SESSION=$(bw unlock --raw)";
    };
  };

  programs = {
    home-manager.enable = true;

    git = {
      enable = true;
      settings = {
        init.defaultBranch = "main";
        pull.rebase = true;
        diff.tool = "nvimdiff";
      };
    };

    gh = {
      enable = true;
      gitCredentialHelper = {
        enable = true;
      };
    };

    ### Bash Shell
    bash = {
      enable = true;
      # initExtra = ''
      #   if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
      #   then
      #     shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
      #     exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
      #   fi
      # '';
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
        {
          name = "grc";
          src = pkgs.fishPlugins.grc.src;
        }
        {
          name = "done";
          src = pkgs.fishPlugins.done;
        }
        {
          name = "fzf-fish";
          src = pkgs.fishPlugins.fzf-fish;
        }
        {
          name = "forgit";
          src = pkgs.fishPlugins.forgit;
        }
      ];
    };

    starship = {
      enable = true;
      # Configuration written to ~/.config/starship.toml
      settings = (with builtins; fromTOML (readFile ../../programs/starship/bracketed-segments.toml)) // {
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
      settings = {
        ignorecase = true;
      };
      extraConfig = ''
        set mouse=a
        set cursorline
      '';
    };

    ## Tmux
    tmux = {
      enable = true;
      shell = "${pkgs.zsh}/bin/zsh";
      terminal = "tmux-256color";
      historyLimit = 100000;
      escapeTime = 300;
      plugins = with pkgs.tmuxPlugins; [
        catppuccin
        # nord
        resurrect
        continuum
        tmux-floax
        {
          plugin = tmux-which-key;
          extraConfig = ''
            set -g @tmux-which-key-xdg-enable 1
            set -g @tmux-which-key-disable-autobuild 1
          '';
        }
      ];

      extraConfig = ''
        set -g mouse
        unbind r
        bind r source-file ~/.config/tmux/tmux.conf
        # set -g prefix C-d

        # Set prefix key to Ctrl-a
        set -g prefix C-a
        unbind C-b
        bind C-a send-prefix

        # Seamless pane navigation with Ctrl-h,j,k,l
        bind-key h select-pane -L
        bind-key j select-pane -D
        bind-key k select-pane -U
        bind-key l select-pane -R

        # Floax
        unbind C-t
        set -g @floax-bind 't'

        # Visuals
        set -g @catppuccin_flavor 'frappe'
        set -g @catppuccin_window_status_style "slant"
        set -g @catppuccin_status_background "none"
        set -g @catppuccin_window_status_style "none"
        set -g @catppuccin_pane_status_enabled "off"
        set -g @catppuccin_pane_border_status "off"


        # Configure left look and feel
        set -g status-left-length 100
        set -g status-left ""
        set -ga status-left "#{?client_prefix,#{#[bg=#{@thm_red},fg=#{@thm_bg},bold]  #S },#{#[bg=#{@thm_bg},fg=#{@thm_green}]  #S }}"
        set -ga status-left "#[bg=#{@thm_bg},fg=#{@thm_overlay_0},none]│"
        set -ga status-left "#[bg=#{@thm_bg},fg=#{@thm_maroon}]  #{pane_current_command} "
        set -ga status-left "#[bg=#{@thm_bg},fg=#{@thm_overlay_0},none]│"
        set -ga status-left "#[bg=#{@thm_bg},fg=#{@thm_blue}]  #{=/-32/...:#{s|$USER|~|:#{b:pane_current_path}}} "
        set -ga status-left "#[bg=#{@thm_bg},fg=#{@thm_overlay_0},none]#{?window_zoomed_flag,│,}"
        set -ga status-left "#[bg=#{@thm_bg},fg=#{@thm_yellow}]#{?window_zoomed_flag,  zoom ,}"
        set -g @catppuccin_directory_text "#{pane_current_path}"
        set -g @catppuccin_date_time_text "%H:%M:%S"


        # status right look and feel
        set -g status-right-length 100
        set -g status-right ""
        # set -ga status-right "#{?#{e|>=:10,#{battery_percentage}},#{#[bg=#{@thm_red},fg=#{@thm_bg}]},#{#[bg=#{@thm_bg},fg=#{@thm_pink}]}} #{battery_icon} #{battery_percentage} "
        set -ga status-right "#[bg=#{@thm_bg},fg=#{@thm_overlay_0}, none]│"
        # set -ga status-right "#[bg=#{@thm_bg}]#{?#{==:#{online_status},ok},#[fg=#{@thm_mauve}] 󰖩 on ,#[fg=#{@thm_red},bold]#[reverse] 󰖪 off }"
        set -ga status-right "#[bg=#{@thm_bg},fg=#{@thm_overlay_0}, none]│"
        set -ga status-right "#[bg=#{@thm_bg},fg=#{@thm_blue}] 󰭦 %Y-%m-%d 󰅐 %H:%M "

        set -ga terminal-overrides ',xterm-256color:Tc'
        set -g @resurrect-processes 'pipes asciiquarium cbonsai fireplace cmatrix pipes'

        # Configure Tmux
        set -g status-position top
        set -g status-style "bg=#{@thm_bg}"
        set -g status-justify "absolute-centre"

        # pane border look and feel
        setw -g pane-border-status top
        setw -g pane-border-format ""
        setw -g pane-active-border-style "bg=#{@thm_bg},fg=#{@thm_overlay_0}"
        setw -g pane-border-style "bg=#{@thm_bg},fg=#{@thm_surface_0}"
        setw -g pane-border-lines single

        # window look and feel
        set -wg automatic-rename on
        set -g automatic-rename-format "Window"

        set -g window-status-format " #I#{?#{!=:#{window_name},Window},: #W,} "
        set -g window-status-style "bg=#{@thm_bg},fg=#{@thm_rosewater}"
        set -g window-status-last-style "bg=#{@thm_bg},fg=#{@thm_peach}"
        set -g window-status-activity-style "bg=#{@thm_red},fg=#{@thm_bg}"
        set -g window-status-bell-style "bg=#{@thm_red},fg=#{@thm_bg},bold"
        set -gF window-status-separator "#[bg=#{@thm_bg},fg=#{@thm_overlay_0}]│"

        set -g window-status-current-format " #I#{?#{!=:#{window_name},Window},: #W,} "
        set -g window-status-current-style "bg=#{@thm_peach},fg=#{@thm_bg},bold"
      '';
    };

    zellij = {
      enable = true;
      # enableFishIntegration = true;
      settings = {
        theme = "nord";
        font = "FiraCode Nerd Font";
        keybinds = {
          normal = { };
          pane = { };
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
