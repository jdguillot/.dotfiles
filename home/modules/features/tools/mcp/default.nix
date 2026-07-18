{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.tools.mcp;
  dotfilesPath = "${config.home.homeDirectory}/.dotfiles";
  projectsPath = "${config.home.homeDirectory}/projects";
in
{
  options.cyberfighter.features.tools.mcp = {
    enable = lib.mkEnableOption "shared MCP servers for AI coding assistants" // {
      default = true;
    };

    enableFilesystem = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose local directories through the filesystem MCP server.";
    };

    enableNix = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose NixOS and Home Manager search tools through mcp-nixos.";
    };

    enableAwesomeCopilot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose the awesome-copilot MCP server for discovering Copilot customizations.";
    };

    enablePlaywright = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose browser automation through the Playwright MCP server.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Single source of truth for MCP servers; consumers below pick these up.
    programs.mcp = {
      enable = true;
      servers =
        (lib.optionalAttrs cfg.enableFilesystem {
          filesystem = {
            command = "${pkgs.mcp-server-filesystem}/bin/mcp-server-filesystem";
            args = [
              dotfilesPath
              projectsPath
            ];
          };
        })
        // (lib.optionalAttrs cfg.enableNix {
          nixos = {
            command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
          };
        })
        // (lib.optionalAttrs cfg.enableAwesomeCopilot {
          awesome-copilot = {
            command = "docker";
            args = [
              "run"
              "-i"
              "--rm"
              "ghcr.io/microsoft/mcp-dotnet-samples/awesome-copilot:latest"
            ];
          };
        })
        // (lib.optionalAttrs cfg.enablePlaywright {
          # Wrapped by nixpkgs with its own chromium (PLAYWRIGHT_BROWSERS_PATH),
          # so it works without a system browser install.
          playwright = {
            command = "${pkgs.playwright-mcp}/bin/playwright-mcp";
          };
        });
    };

    # Copilot CLI: generates ~/.copilot/mcp-config.json from programs.mcp.
    # The binary itself is installed system-wide (cyberfighter.packages).
    programs.github-copilot-cli = {
      enable = true;
      package = null;
      enableMcpIntegration = true;
    };

    # OpenCode: servers are merged into ~/.config/opencode/opencode.json.
    programs.opencode.enableMcpIntegration = true;

    # Claude Code has no declarative config file for user-scope MCP servers;
    # it only reads them from the mutable ~/.claude.json. Merge the generated
    # ~/.config/mcp/mcp.json into it at activation time. Declared servers win
    # on name collisions, manually added servers are preserved.
    home.activation.claudeMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      claudeJson="${config.home.homeDirectory}/.claude.json"
      mcpJson="${config.xdg.configHome}/mcp/mcp.json"
      if [ -f "$mcpJson" ]; then
        if [ -v DRY_RUN ]; then
          verboseEcho "Would merge MCP servers from $mcpJson into $claudeJson"
        elif [ ! -f "$claudeJson" ]; then
          ${pkgs.jq}/bin/jq '{ mcpServers: .mcpServers }' "$mcpJson" > "$claudeJson"
        else
          tmp=$(mktemp)
          ${pkgs.jq}/bin/jq --slurpfile mcp "$mcpJson" \
            '.mcpServers = ((.mcpServers // {}) + $mcp[0].mcpServers)' \
            "$claudeJson" > "$tmp" && mv "$tmp" "$claudeJson"
        fi
      fi
    '';
  };
}
