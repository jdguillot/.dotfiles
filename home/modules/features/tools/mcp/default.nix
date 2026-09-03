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
  githubReady = wanted "github" && secretsYamlExists && config.cyberfighter.features.sops.enable;

  # One catalog drives everything; per-entry `default` decides whether a
  # server ships globally, and cfg.use.<name> overrides it per home.
  # Servers defaulting off cost context in every session for clients that
  # load schemas upfront (opencode, Copilot) -- scope those to the repos
  # that need them via project config instead (.mcp.json for Claude Code,
  # opencode.json for opencode); the mcp-nixos binary ships in devPackages
  # so bare commands resolve.
  catalog = {
    filesystem = {
      default = true;
      server = {
        command = "${pkgs.mcp-server-filesystem}/bin/mcp-server-filesystem";
        args = [
          dotfilesPath
          projectsPath
        ];
      };
    };

    # Prefer per-project config in nix-heavy repos.
    nixos = {
      default = false;
      server.command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
    };

    # The gh CLI covers the same ground from Bash at zero standing context
    # cost; only usable on hosts whose user age key is a recipient of
    # secrets/secrets.yaml.
    github = {
      default = false;
      server = {
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
    };

    context7 = {
      default = true;
      server = {
        command = "${pkgs.context7-mcp}/bin/context7-mcp";
        env = lib.optionalAttrs (cfg.context7ApiKey != null) {
          CONTEXT7_API_KEY = cfg.context7ApiKey;
        };
      };
    };

    # curl covers most retrieval from Bash.
    fetch = {
      default = false;
      server.command = "${pkgs.mcp-server-fetch}/bin/mcp-server-fetch";
    };

    # Superseded by the agent-browser CLI (tools.agentBrowser). Wrapped by
    # nixpkgs with its own chromium (PLAYWRIGHT_BROWSERS_PATH), so it works
    # without a system browser install.
    playwright = {
      default = false;
      server.command = "${pkgs.playwright-mcp}/bin/playwright-mcp";
    };
  };

  wanted = name: cfg.use.${name} or catalog.${name}.default;
  # github additionally needs the sops guard above.
  active = name: if name == "github" then githubReady else wanted name;
in
{
  options.cyberfighter.features.tools.mcp = {
    enable = lib.mkEnableOption "shared MCP servers for AI coding assistants" // {
      default = config.cyberfighter.traits.dev;
      defaultText = lib.literalExpression "config.cyberfighter.traits.dev";
    };

    use = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = { };
      example = lib.literalExpression ''{ github = true; playwright = true; }'';
      description = "Per-server overrides of the catalog defaults (${lib.concatStringsSep ", " (lib.attrNames catalog)}).";
    };

    githubTokenSecret = lib.mkOption {
      type = lib.types.str;
      default = "github-pat";
      description = "Name of the sops secret holding the GitHub token, expected in secrets/secrets.yaml. Only usable on hosts whose user age key is a recipient of that file.";
    };

    context7ApiKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "ctx7-...";
      description = "Optional Context7 API key; without it the anonymous free tier is used.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.use == { } || lib.all (n: catalog ? ${n}) (lib.attrNames cfg.use);
        message = "cyberfighter.features.tools.mcp.use names unknown servers: ${lib.concatStringsSep ", " (lib.filter (n: !(catalog ? ${n})) (lib.attrNames cfg.use))}. Known: ${lib.concatStringsSep ", " (lib.attrNames catalog)}.";
      }
    ];

    # sopsFile override; only works where the user age key is a recipient
    # of secrets/secrets.yaml -- gate use.github per host.
    sops.secrets.${cfg.githubTokenSecret} = lib.mkIf githubReady {
      sopsFile = secretsYaml;
    };
    # Single source of truth for MCP servers; consumers below pick these up.
    programs.mcp = {
      enable = true;
      servers = lib.mapAttrs (_: entry: entry.server) (
        lib.filterAttrs (name: _: active name) catalog
      );
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
