{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.tools.copilotMcp;
  dotfilesPath = "${config.home.homeDirectory}/.dotfiles";
  projectsPath = "${config.home.homeDirectory}/projects";
  servers =
    (lib.optionalAttrs cfg.enableFilesystem {
      filesystem = {
        type = "stdio";
        command = "${pkgs.mcp-server-filesystem}/bin/mcp-server-filesystem";
        args = [
          dotfilesPath
          projectsPath
        ];
        tools = [ "*" ];
      };
    })
    // (lib.optionalAttrs cfg.enableNix {
      nixos = {
        type = "stdio";
        command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
        args = [ ];
        tools = [ "*" ];
      };
    })
    // (lib.optionalAttrs cfg.enableAwesomeCopilot {
      awesome-copilot = {
        type = "stdio";
        command = "docker";
        args = [
          "run"
          "-i"
          "--rm"
          "ghcr.io/microsoft/mcp-dotnet-samples/awesome-copilot:latest"
        ];
        tools = [ "*" ];
      };
    });
in
{
  options.cyberfighter.features.tools.copilotMcp = {
    enable = lib.mkEnableOption "GitHub Copilot MCP servers" // {
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
  };

  config = lib.mkIf cfg.enable {
    home.file.".copilot/mcp-config.json".text = builtins.toJSON {
      mcpServers = servers;
    };
  };
}
