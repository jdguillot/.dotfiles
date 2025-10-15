{ pkgs, pkgs-temp, flake-inputs, ... }:

{

  imports = [
    ../programs/lazygit.nix
    # ../programs/neovim.nix
    ../programs/zsh.nix
    ../programs/btop/btop.nix
];


  home = {
    stateVersion = "25.05"; # Please read the comment before changing.

    # The home.packages option allows you to install Nix packages into your
    # environment.
    packages = with pkgs; [
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
      clang-tools
      gcc
      pay-respects
      devenv
      nix-your-shell
      dua
      lazyssh
      flake-inputs.isd.packages.${system}.default
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
    ] ++ [
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
      pysrc = ". .venv/bin/activate";
      pynew = "python -m venv .venv && pysrc && pip install -r requirements";
      
      nswitch = "sudo nixos-rebuild switch --flake ~/.dotfiles";
      nupdate = "nix flake update --flake ~/.dotfiles";
      nboot = "sudo nixos-rebuild boot --flake ~/.dotfiles";

      myip = "curl http://ip-api.com/json/ -s | jq";

      dadjoke = "curl -s -H \"Accept: text/plain\" https://icanhazdadjoke.com | cowsay -f sus | lolcat";
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
      shell = "${pkgs.zsh}/bin/zsh";
      terminal = "xterm-256color";
      historyLimit = 100000;
      plugins = with pkgs;
        [
          {
            # plugin = tmuxPlugins.catppuccin;
            plugin = tmuxPlugins.nord;
          }
          
          tmuxPlugins.resurrect
          tmuxPlugins.continuum

        ];
      extraConfig = ''
        set -g mouse
        unbind r
        bind r source-file ~/.config/tmux/tmux.conf
        set -g prefix C-d
        set -ga terminal-overrides ',xterm-256color:Tc'
        set -g @resurrect-processes 'pipes asciiquarium cbonsai fireplace cmatrix pipes'
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
