{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.tools.copilotMcp;
  dotfilesPath = "${config.home.homeDirectory}/.dotfiles";
  servers =
    (lib.optionalAttrs cfg.enableFilesystem {
      filesystem = {
        type = "stdio";
        command = "${pkgs.nodejs}/bin/npx";
        args = [
          "-y"
          "@modelcontextprotocol/server-filesystem"
          dotfilesPath
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
      description = "Expose the dotfiles repository through the filesystem MCP server.";
    };

    enableNix = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose NixOS and Home Manager search tools through mcp-nixos.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.file.".copilot/mcp-config.json".text = builtins.toJSON {
      mcpServers = servers;
    };
  };
}
