{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.editor.lazyvim;
in
{
  options.cyberfighter.features.editor.lazyvim = {
    enable = lib.mkEnableOption "LazyVim neovim configuration";

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
        markdownlint-cli2
      ];
      description = "Extra packages to install for LazyVim";
    };

    languageServers = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
        lua-language-server
        nodePackages.typescript-language-server
        jdt-language-server
        yaml-language-server
        nixd
      ];
      description = "Language servers to install";
    };

    formatters = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
        stylua
        prettier
        nixfmt-rfc-style
        statix
      ];
      description = "Code formatters to install";
    };

    treesitterParsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "c"
        "lua"
        "nix"
        "yaml"
        "javascript"
        "java"
        "typescript"
        "tsx"
        "json"
        "markdown"
        "markdown_inline"
        "bash"
        "vim"
        "vimdoc"
        "regex"
        "dockerfile"
      ];
      description = "Treesitter parsers to install";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = cfg.extraPackages;

    programs.neovim = {
      enable = true;
      viAlias = true;
      vimAlias = true;

      extraPackages =
        with pkgs;
        [
          ripgrep
        ]
        ++ cfg.languageServers
        ++ cfg.formatters;

      plugins = with pkgs.vimPlugins; [
        lazy-nvim
        markdown-preview-nvim
      ];

      extraLuaConfig =
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
            opencode-nvim
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
              { import = "lazyvim.plugins.extras.ai.copilot" },
              { import = "lazyvim.plugins.extras.ai.copilot-chat" },
              { import = "lazyvim.plugins.extras.ui.edgy" },
              { import = "lazyvim.plugins.extras.editor.harpoon2" },
              { import = "lazyvim.plugins.extras.lang.markdown" },
              { import = "lazyvim.plugins.extras.lang.nix" },
              { import = "lazyvim.plugins.extras.lang.yaml" },
              { import = "lazyvim.plugins.extras.lang.java" },
              { import = "lazyvim.plugins.extras.coding.mini-surround" },
              { import = "lazyvim.plugins.extras.editor.overseer" },
              { import = "lazyvim.plugins.extras.coding.yanky" },
              { import = "lazyvim.plugins.extras.dap.core" },
              { import = "lazyvim.plugins.extras.lang.ember" },
              { import = "lazyvim.plugins.extras.formatting.prettier" },

              -- The following configs are needed for fixing lazyvim on nix
              -- force enable telescope-fzf-native.nvim
              { "nvim-telescope/telescope-fzf-native.nvim", enabled = true },
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
      in
      "${parsers}/parser";

    # Normal LazyVim config here, see https://github.com/LazyVim/starter/tree/main/lua
    xdg.configFile."nvim/lua".source = ./lua;
  };
}
