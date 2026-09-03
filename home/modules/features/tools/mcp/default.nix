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
  # Needs an explicit sopsFile override (home-manager sops only reads
  # secrets_common.yaml). enableGitHub must stay off where the user key
  # cannot decrypt it -- one undecryptable file kills the whole user unit.
  secretsYaml = ../../../../../secrets/secrets.yaml;
  secretsYamlExists = builtins.pathExists secretsYaml;
  # Only wire the token when sops is on for this home: declaring a secret
  # without a key source trips sops-nix's assertion.
  githubReady = cfg.enableGitHub && secretsYamlExists && config.cyberfighter.features.sops.enable;
in
{
  options.cyberfighter.features.tools.mcp = {
    enable = lib.mkEnableOption "shared MCP servers for AI coding assistants" // {
      default = config.cyberfighter.traits.dev;
      defaultText = lib.literalExpression "config.cyberfighter.traits.dev";
    };

    enableFilesystem = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose local directories through the filesystem MCP server.";
    };

    # Domain-specific servers default off: schemas cost context in every
    # session for clients that load them upfront (opencode, Copilot).
    # Scope them to the repos that need them via project config instead
    # (.mcp.json for Claude Code, opencode.json for opencode) -- the
    # mcp-nixos binary ships in devPackages so bare commands resolve.
    enableNix = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Expose NixOS and Home Manager search tools through mcp-nixos globally; prefer per-project config in nix-heavy repos.";
    };

    enableGitHub = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Expose GitHub's official MCP server globally; the gh CLI covers the same ground from Bash at zero standing context cost.";
    };

    githubTokenSecret = lib.mkOption {
      type = lib.types.str;
      default = "github-pat";
      description = "Name of the sops secret holding the GitHub token, expected in secrets/secrets.yaml. Only usable on hosts whose user age key is a recipient of that file.";
    };

    enableContext7 = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose the Context7 MCP server for up-to-date library documentation.";
    };

    context7ApiKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "ctx7-...";
      description = "Optional Context7 API key; without it the anonymous free tier is used.";
    };

    enableFetch = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Expose the fetch MCP server globally; curl covers most retrieval from Bash.";
    };

    enablePlaywright = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Expose browser automation through the Playwright MCP server; superseded by the agent-browser CLI (tools.agentBrowser).";
    };
  };

  config = lib.mkIf cfg.enable {
    # sopsFile override; only works where the user age key is a recipient
    # of secrets/secrets.yaml -- gate enableGitHub per host.
    sops.secrets.${cfg.githubTokenSecret} = lib.mkIf githubReady {
      sopsFile = secretsYaml;
    };
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
        // (lib.optionalAttrs githubReady {
          github = {
            command = "${pkgs.github-mcp-server}/bin/github-mcp-server";
            # The default subcommand prints help and exits; `stdio` starts the MCP server.
            args = [ "stdio" ];
            env = {
              # File reference: the token is decrypted into a 0400 secret path by
              # sops-nix and handed to the process, never written into the config.
              GITHUB_PERSONAL_ACCESS_TOKEN = {
                file = config.sops.secrets.${cfg.githubTokenSecret}.path;
              };
            };
          };
        })
        // (lib.optionalAttrs cfg.enableContext7 {
          context7 = {
            command = "${pkgs.context7-mcp}/bin/context7-mcp";
            env = lib.optionalAttrs (cfg.context7ApiKey != null) {
              CONTEXT7_API_KEY = cfg.context7ApiKey;
            };
          };
        })
        // (lib.optionalAttrs cfg.enableFetch {
          fetch = {
            command = "${pkgs.mcp-server-fetch}/bin/mcp-server-fetch";
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

    # Claude Code only reads user-scope servers from mutable ~/.claude.json;
    # merge at activation (declared servers win, manual ones preserved).
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
