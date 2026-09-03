{
  config,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.features.tools.lsp;

  # One server table feeds both Claude Code and opencode. Commands are
  # bare names resolved from PATH: config-language servers ship in
  # devPackages (shared with LazyVim), toolchain servers (rust-analyzer,
  # typescript-language-server) come from each project's dev shell so
  # they match the project's pinned toolchain; a missing binary just
  # means no diagnostics for that language.
  servers = {
    nix = {
      command = "nixd";
      args = [ ];
      extensions = {
        ".nix" = "nix";
      };
    };
    yaml = {
      command = "yaml-language-server";
      args = [ "--stdio" ];
      extensions = {
        ".yaml" = "yaml";
        ".yml" = "yaml";
      };
    };
    bash = {
      command = "bash-language-server";
      args = [ "start" ];
      extensions = {
        ".sh" = "shellscript";
        ".bash" = "shellscript";
      };
    };
    lua = {
      command = "lua-language-server";
      args = [ ];
      extensions = {
        ".lua" = "lua";
      };
    };
    json = {
      command = "vscode-json-languageserver";
      args = [ "--stdio" ];
      extensions = {
        ".json" = "json";
        ".jsonc" = "jsonc";
      };
    };
    rust = {
      command = "rust-analyzer";
      args = [ ];
      extensions = {
        ".rs" = "rust";
      };
    };
    typescript = {
      command = "typescript-language-server";
      args = [ "--stdio" ];
      extensions = {
        ".ts" = "typescript";
        ".tsx" = "typescriptreact";
        ".js" = "javascript";
        ".jsx" = "javascriptreact";
      };
    };
  };
in
{
  options.cyberfighter.features.tools.lsp = {
    enable = lib.mkEnableOption "shared LSP diagnostics for AI coding assistants" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    # Rendered into a generated "hm" plugin's .lsp.json by home-manager.
    programs.claude-code.lspServers = lib.mapAttrs (_: s: {
      inherit (s) command args;
      extensionToLanguage = s.extensions;
    }) servers;

    # opencode auto-downloads LSP binaries, which cannot run on NixOS;
    # declare PATH-resolved servers and disable the downloader.
    programs.opencode.settings.lsp = lib.mapAttrs (_: s: {
      command = [ s.command ] ++ s.args;
      extensions = lib.attrNames s.extensions;
    }) servers;

    home.sessionVariables.OPENCODE_DISABLE_LSP_DOWNLOAD = "true";
  };
}
