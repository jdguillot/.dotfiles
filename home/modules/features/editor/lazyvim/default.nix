{
  config,
  lib,
  pkgs,
  hostMeta,
  ...
}:

let
  cfg = config.cyberfighter.features.editor.lazyvim;
in
{
  options.cyberfighter.features.editor.lazyvim = {
    enable = lib.mkEnableOption "LazyVim neovim configuration";

    dev = lib.mkOption {
      type = lib.types.bool;
      default = config.cyberfighter.traits.dev;
      defaultText = lib.literalExpression "config.cyberfighter.traits.dev";
      description = "Full dev setup (LSPs, language extras, DAP, copilot, formatters, notes stack). When false, LazyVim is a pure editor: theme, navigation, treesitter basics.";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [ ];
      description = "Extra packages to install for LazyVim";
    };

    languageServers = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = lib.optionals cfg.dev (
        with pkgs;
        [
          lua-language-server
          typescript-language-server
          jdt-language-server
          yaml-language-server
          nixd
          rust-analyzer
        ]
      );
      description = "Language servers to install (empty unless dev)";
    };

    formatters = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = lib.optionals cfg.dev (
        with pkgs;
        [
          stylua
          prettier
          nixfmt
          statix
        ]
      );
      description = "Code formatters to install (empty unless dev)";
    };

    treesitterParsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "bash"
        "diff"
        "json"
        "lua"
        "markdown"
        "markdown_inline"
        "nix"
        "regex"
        "toml"
        "vim"
        "vimdoc"
        "yaml"
      ]
      ++ lib.optionals cfg.dev [
        "c"
        "css"
        "dockerfile"
        "html"
        "java"
        "javascript"
        "json5"
        "python"
        "rust"
        "tsx"
        "typescript"
        "xml"
      ];
      description = "Treesitter parsers to install (language parsers added with dev)";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      lib.optionals cfg.dev (
        with pkgs;
        [
          markdownlint-cli2
          # Wrap marksman with ICU library path for .NET runtime
          (pkgs.writeShellScriptBin "marksman" ''
            export LD_LIBRARY_PATH="${pkgs.icu}/lib:$LD_LIBRARY_PATH"
            exec ${pkgs.marksman}/bin/marksman "$@"
          '')
          tailwindcss-language-server
          vscode-langservers-extracted
        ]
      )
      ++ cfg.extraPackages;

    programs.neovim = {
      enable = true;
      viAlias = true;
      vimAlias = true;
      # No legacy pynvim/ruby-host plugins in use; opt into the new
      # upstream defaults (false) and drop the provider wrappers.
      withRuby = false;
      withPython3 = false;

      extraLuaPackages =
        ps: with ps; [
          lua-utils-nvim
          pathlib-nvim
          nvim-nio
        ];

      extraPackages =
        with pkgs;
        [
          ripgrep
          luarocks
        ]
        ++ cfg.languageServers
        ++ cfg.formatters;

      plugins = with pkgs.vimPlugins; [
        lazy-nvim
      ];

      initLua =
        let
          plugins = with pkgs.vimPlugins; [
            LazyVim
            bufferline-nvim
            cmp-buffer
            cmp-nvim-lsp
            cmp-path
            cmp_luasnip
            conform-nvim
            dashboard-nvim
            dressing-nvim
            flash-nvim
            friendly-snippets
            gitsigns-nvim
            indent-blankline-nvim
            lualine-nvim
            neo-tree-nvim
            neoconf-nvim
            neodev-nvim
            noice-nvim
            nui-nvim
            nvim-cmp
            nvim-lint
            nvim-lspconfig
            nvim-notify
            nvim-spectre
            nvim-web-devicons
            persistence-nvim
            plenary-nvim
            telescope-fzf-native-nvim
            telescope-nvim
            todo-comments-nvim
            tokyonight-nvim
            trouble-nvim
            vim-illuminate
            vim-startuptime
            which-key-nvim
            remote-nvim-nvim
            colorful-winsep-nvim
            {
              name = "LuaSnip";
              path = luasnip;
            }
            {
              name = "catppuccin";
              path = catppuccin-nvim;
            }
            {
              name = "onenord";
              path = onenord-nvim;
            }
            {
              name = "nordic";
              path = nordic-nvim;
            }
            {
              name = "mini.ai";
              path = mini-nvim;
            }
            {
              name = "mini.bufremove";
              path = mini-nvim;
            }
            {
              name = "mini.comment";
              path = mini-nvim;
            }
            {
              name = "mini.indentscope";
              path = mini-nvim;
            }
            {
              name = "mini.pairs";
              path = mini-nvim;
            }
            {
              name = "mini.surround";
              path = mini-nvim;
            }
            # {
            #   name = "mini.hipatterns";
            #   path = mini-nvim;
            # }
            mini-hipatterns
            markdown-preview-nvim
            vim-table-mode
            neorg
          ];
          mkEntryFromDrv =
            drv:
            if lib.isDerivation drv then
              {
                name = "${lib.getName drv}";
                path = drv;
              }
            else
              drv;
          lazyPath = pkgs.linkFarm "lazy-plugins" (builtins.map mkEntryFromDrv plugins);
        in
        ''
          -- Dev-gated plugin specs in lua/plugins/*.lua check this flag.
          vim.g.dotfiles_dev = ${lib.boolToString cfg.dev}

          require("lazy").setup({
            defaults = {
              lazy = true,
            },
            dev = {
              -- reuse files from pkgs.vimPlugins.*
              path = "${lazyPath}",
              patterns = { "" },
              -- fallback to download
              fallback = true,
            },
            spec = {
              { "LazyVim/LazyVim", import = "lazyvim.plugins" },

              -- Nix-managed extras (must come after lazyvim.plugins but before your plugins)
              { import = "lazyvim.plugins.extras.util.dot" },
              { import = "lazyvim.plugins.extras.ui.edgy" },
              { import = "lazyvim.plugins.extras.editor.harpoon2" },
              { import = "lazyvim.plugins.extras.coding.mini-surround" },
              { import = "lazyvim.plugins.extras.coding.yanky" },
              { import = "lazyvim.plugins.extras.util.mini-hipatterns"},
              { import = "lazyvim.plugins.extras.editor.snacks_explorer"},
              { import = "lazyvim.plugins.extras.editor.mini-diff"},
        ''
        + lib.optionalString cfg.dev ''
              -- Dev-trait extras: languages, DAP, AI, formatting. The
              -- markdown/notes extras ride here until a notes trait exists.
              { import = "lazyvim.plugins.extras.ai.copilot" },
              -- { import = "lazyvim.plugins.extras.ai.copilot-native" }, -- waiting on blink to support accepting word by word
              { import = "lazyvim.plugins.extras.ai.sidekick" },
              { import = "lazyvim.plugins.extras.lang.markdown" },
              { import = "lazyvim.plugins.extras.lang.nix" },
              { import = "lazyvim.plugins.extras.lang.yaml" },
              { import = "lazyvim.plugins.extras.lang.java" },
              { import = "lazyvim.plugins.extras.lang.json" },
              { import = "lazyvim.plugins.extras.lang.python" },
              { import = "lazyvim.plugins.extras.lang.typescript" },
              { import = "lazyvim.plugins.extras.lang.rust" },
              { import = "lazyvim.plugins.extras.dap.core" },
              { import = "lazyvim.plugins.extras.lang.ember" },
              { import = "lazyvim.plugins.extras.formatting.prettier" },
              { import = "lazyvim.plugins.extras.lang.tailwind"},
              { import = "lazyvim.plugins.extras.util.gh"},
              { import = "lazyvim.plugins.extras.lang.git"},
        ''
        + ''

              -- The following configs are needed for fixing lazyvim on nix
              -- force enable telescope-fzf-native.nvim
              -- { "nvim-telescope/telescope-fzf-native.nvim", enabled = true },
              -- disable mason.nvim, use programs.neovim.extraPackages
              { "mason-org/mason-lspconfig.nvim", enabled = false },
              { "mason-org/mason.nvim", enabled = false },
              -- import/override with your plugins
              { import = "plugins" },
              -- treesitter handled by xdg.configFile."nvim/parser", put this line at the end of spec to clear ensure_installed
              { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = {} } },
            },
          })
        '';

    };

    # https://github.com/nvim-treesitter/nvim-treesitter#i-get-query-error-invalid-node-type-at-position
    xdg.configFile."nvim/parser".source =
      let
        parsers = pkgs.symlinkJoin {
          name = "treesitter-parsers";
          paths =
            (pkgs.vimPlugins.nvim-treesitter.withPlugins (
              plugins: builtins.map (parser: plugins.${parser}) cfg.treesitterParsers
            )).dependencies;
        };
        # Add norg parsers from tree-sitter-grammars
        norgParser = pkgs.tree-sitter-grammars.tree-sitter-norg;
        norgMetaParser = pkgs.tree-sitter-grammars.tree-sitter-norg-meta;
        allParsers = pkgs.symlinkJoin {
          name = "all-treesitter-parsers";
          paths = [ parsers ];
          postBuild = ''
            # Link norg parsers
            ln -sf ${norgParser}/parser $out/parser/norg.so
            ln -sf ${norgMetaParser}/parser $out/parser/norg_meta.so
          '';
        };
      in
      "${allParsers}/parser";

    # Normal LazyVim config here, see https://github.com/LazyVim/starter/tree/main/lua
    xdg.configFile."nvim/lua".source = ./lua;
    xdg.configFile."nvim/snippets".source = ./snippets;

    # Every flake host, so nixd.lua can point the NixOS option provider at
    # whichever host's file is in the current buffer. Host attribute name,
    # hostname and hosts/ directory are all the same string, so only the
    # home-manager configuration name needs mapping.
    # Only nixd.lua reads this, and nixd only runs with the dev trait.
    home.file.".dotfiles/.nixd-hosts.json" = lib.mkIf cfg.dev {
      text =
        let
          hostConfigs = import ../../../../../hosts/default.nix;
        in
        builtins.toJSON {
          default = hostMeta.system.hostname;
          hosts = lib.mapAttrs (name: meta: {
            home = "${meta.system.username}@${name}";
          }) hostConfigs;
        };
    };
  };
}
