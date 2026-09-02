# Hermes Agent (Nous Research) -- https://hermes-agent.nousresearch.com
#
# Thin `cyberfighter.features.ai.hermes` wrapper around the upstream NixOS
# module (`inputs.hermes-agent.nixosModules.default`), following the setup
# documented at /docs/getting-started/nix-setup.
#
# Two ways to configure the agent itself:
#   * configFile = null (default) -- the config is generated from `model`,
#     `settings` and `mcpServers`, and deep-merged with runtime edits on disk.
#   * configFile = <path>  -- that YAML is installed verbatim as
#     $HERMES_HOME/config.yaml, and upstream ignores `settings` entirely; a
#     host that wants its whole agent behaviour in one readable file points
#     this at its own YAML (see hosts/ryzn-server/hermes-config.yaml).
#
# Everything that is *not* part of config.yaml (service user, state dir,
# backend, container mode, secrets wiring) is exposed regardless of the mode.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.cyberfighter.features.ai.hermes;
  sopsEnabled = config.cyberfighter.features.sops.enable or false;

  # Options that only take effect when Hermes generates config.yaml itself.
  usesNixSettings = cfg.model != null || cfg.settings != { } || cfg.mcpServers != { };

  envSecretPath = lib.optional (
    cfg.secrets.envSecret != null && sopsEnabled
  ) config.sops.secrets.${cfg.secrets.envSecret}.path;
in
{
  imports = [ inputs.hermes-agent.nixosModules.default ];

  options.cyberfighter.features.ai.hermes = {
    enable = lib.mkEnableOption "Hermes Agent gateway";

    configFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = lib.literalExpression "./hermes-config.yaml";
      description = ''
        A config.yaml installed verbatim as $HERMES_HOME/config.yaml, so a
        host's whole agent behaviour stays in one readable YAML file.

        Upstream treats this as an escape hatch: when it is non-null, the
        `model`, `settings` and `mcpServers` options below are ignored. Left
        null, the config is generated from those options instead.
      '';
    };

    model = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "anthropic/claude-sonnet-5";
      description = ''
        Default model, as "provider/model". Written to `model` in the generated
        config.yaml. Requires `configFile = null`.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      example = lib.literalExpression ''
        {
          toolsets = [ "hermes-cli" ];
          terminal = {
            backend = "local";
            timeout = 180;
          };
        }
      '';
      description = ''
        Extra config.yaml keys, deep-merged into the generated config.
        Requires `configFile = null`.
      '';
    };

    mcpServers = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      example = lib.literalExpression ''
        {
          filesystem = {
            command = "npx";
            args = [ "-y" "@modelcontextprotocol/server-filesystem" "/var/lib/hermes/workspace" ];
          };
        }
      '';
      description = ''
        MCP servers, merged into `mcp_servers` in the generated config.yaml.
        Requires `configFile = null`; with a `configFile`, declare them in the
        YAML instead.
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/hermes";
      description = "State directory. Holds .hermes/ (HERMES_HOME) and workspace/.";
    };

    workingDirectory = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Agent working directory, i.e. where its terminal and file tools operate.
        Null keeps the upstream default of "''${stateDir}/workspace".
      '';
    };

    addToSystemPackages = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Put the `hermes` CLI on the system PATH and export HERMES_HOME
        system-wide, so interactive shells share sessions, skills and cron with
        the gateway service instead of creating a private ~/.hermes.
      '';
    };

    groupMembers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "cyberfighter" ];
      description = ''
        Users added to the hermes group. The state directory is 2770
        hermes:hermes, so this is what lets a human actually use the shared
        HERMES_HOME that `addToSystemPackages` points them at.
      '';
    };

    sharedHomePermissions = lib.mkOption {
      type = lib.types.bool;
      default = cfg.addToSystemPackages && cfg.groupMembers != [ ];
      defaultText = lib.literalExpression "addToSystemPackages && groupMembers != [ ]";
      description = ''
        Keep the files directly under HERMES_HOME group-owned and group-rw.

        Needed because upstream re-chmods config.yaml to 0600 on every runtime
        persist (`save_config_value` in cli.py, unconditional -- unlike
        `_secure_file`, it does not honour managed mode). One `/model` or
        `/approvals always` locks every other group member out of the shared
        home: the CLI then silently falls back to the default config, which
        among other things drops `model.base_url` and hides the local Ollama
        catalog from the model picker. The reverse happens too -- caches a
        group member writes come out 0600 and the gateway cannot read them.

        Everyone in the hermes group can already read the 2770 state
        directory, so this grants nothing new.
      '';
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra packages on the agent's PATH (build tools, CLIs it should be able to call).";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Non-secret environment variables written to $HERMES_HOME/.env.
        These land in the world-readable Nix store -- use `secrets.envSecret`
        for anything sensitive.
      '';
    };

    extraEnvironmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Additional runtime paths to environment files appended to
        $HERMES_HOME/.env, on top of the sops secret. Strings, not paths, so
        the file is never copied into the Nix store.
      '';
    };

    secrets = {
      envSecret = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "hermes-env";
        description = ''
          Key in the SOPS file holding a dotenv blob of provider credentials,
          for example:

            hermes-env: |
              ANTHROPIC_API_KEY=sk-ant-...
              OPENROUTER_API_KEY=sk-or-...

          The module declares the `sops.secrets` entry and points
          `environmentFiles` at its runtime path. Null disables the wiring.
        '';
      };

      sopsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "SOPS file holding the secrets. Null uses sops.defaultSopsFile.";
      };
    };

    backend = {
      mode = lib.mkOption {
        type = lib.types.enum [
          "none"
          "serve"
          "dashboard"
        ];
        default = "none";
        description = ''
          Extra backend process alongside the gateway. "serve" exposes the
          /api/ws and /api/pty sockets that Hermes Desktop connects to;
          "dashboard" adds the browser admin panel on the same port.
        '';
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = ''
          Bind address. Anything other than loopback turns on the dashboard's
          auth gate, so set `sessionTokenSecret` too. The server also rejects
          requests whose Host header differs from this value, so use the name
          or address clients actually dial.
        '';
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 9119;
        description = "Backend port.";
      };

      waitFor = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "hostname"
            "interface"
          ]
        );
        default = null;
        example = "interface";
        description = ''
          Poll for the bind target before starting, instead of racing it at
          boot. Use "hostname" for a MagicDNS name, or "interface" together
          with `interfaceName` to bind whatever address that link gets.
        '';
      };

      interfaceName = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "tailscale0";
        description = "Interface to take the bind address from, when waitFor = \"interface\".";
      };

      sessionTokenSecret = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "hermes-dashboard-token";
        description = ''
          Key in the SOPS file holding the backend session token on one line.
          Without it the backend mints a fresh token each start, which no
          other process can know. The module declares the `sops.secrets` entry
          with mode 0400 and points `backend.sessionTokenFile` at it.
        '';
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open `backend.port` in the firewall.";
      };
    };

    container = {
      enable = lib.mkEnableOption ''
        container mode: run the gateway in an Ubuntu OCI container with a
        persistent writable layer, so the agent can apt/pip/npm install things
        that survive restarts. Mutually exclusive with a backend
      '';

      backend = lib.mkOption {
        type = lib.types.enum [
          "docker"
          "podman"
        ];
        default = "docker";
        description = "Container runtime.";
      };

      image = lib.mkOption {
        type = lib.types.str;
        default = "ubuntu:24.04";
        description = "Base image, pulled at runtime.";
      };

      extraVolumes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "/home/cyberfighter/projects:/projects:rw" ];
        description = "Extra volume mounts, in host:container:mode form.";
      };

      hostUsers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Interactive users who get a ~/.hermes symlink to the state directory
          and are added to the hermes group. Container mode only.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = cfg.configFile == null || !usesNixSettings;
            message = ''
              cyberfighter.features.ai.hermes: `configFile` is set, so upstream
              installs that YAML verbatim and ignores `model`, `settings` and
              `mcpServers`. Move those keys into the YAML, or set
              `configFile = null` to generate config.yaml from Nix.
            '';
          }
          {
            assertion = cfg.secrets.envSecret == null || sopsEnabled;
            message = ''
              cyberfighter.features.ai.hermes: `secrets.envSecret` needs
              `cyberfighter.features.sops.enable = true`. Enable SOPS, or set
              `secrets.envSecret = null` and supply credentials through
              `extraEnvironmentFiles`.
            '';
          }
          {
            assertion = cfg.backend.sessionTokenSecret == null || sopsEnabled;
            message = "cyberfighter.features.ai.hermes: `backend.sessionTokenSecret` requires cyberfighter.features.sops.enable = true.";
          }
        ];

        warnings =
          lib.optional
            (
              cfg.backend.mode != "none"
              && cfg.backend.host != "127.0.0.1"
              && cfg.backend.sessionTokenSecret == null
            )
            ''
              cyberfighter.features.ai.hermes: the backend binds to a non-loopback
              address (${cfg.backend.host}) without `backend.sessionTokenSecret`.
              The dashboard's auth gate is active, and every start mints a token
              nothing else knows -- clients will not be able to connect.
            '';

        services.hermes-agent = {
          enable = true;
          inherit (cfg)
            configFile
            stateDir
            addToSystemPackages
            extraPackages
            environment
            ;

          environmentFiles = envSecretPath ++ cfg.extraEnvironmentFiles;

          backend = {
            inherit (cfg.backend)
              mode
              host
              port
              waitFor
              interfaceName
              ;
            sessionTokenFile = lib.mkIf (
              cfg.backend.sessionTokenSecret != null && sopsEnabled
            ) config.sops.secrets.${cfg.backend.sessionTokenSecret}.path;
          };

          container = {
            inherit (cfg.container)
              enable
              backend
              image
              extraVolumes
              hostUsers
              ;
          };
        };
      }

      (lib.mkIf (cfg.workingDirectory != null) {
        services.hermes-agent.workingDirectory = cfg.workingDirectory;
      })

      (lib.mkIf (cfg.configFile == null) {
        services.hermes-agent.settings = lib.recursiveUpdate cfg.settings (
          lib.optionalAttrs (cfg.model != null) { model = cfg.model; }
        );
        services.hermes-agent.mcpServers = cfg.mcpServers;
      })

      (lib.mkIf (cfg.groupMembers != [ ]) {
        users.users = lib.genAttrs cfg.groupMembers (_: {
          extraGroups = [ config.services.hermes-agent.group ];
        });
      })

      (lib.mkIf cfg.sharedHomePermissions {
        # inotify on the directory: every writer here replaces files by
        # rename, so the create/move lands as a directory event and the fixer
        # runs after the offending chmod rather than racing it.
        systemd.paths.hermes-shared-home = {
          description = "Watch HERMES_HOME for files that lost group access";
          wantedBy = [ "multi-user.target" ];
          pathConfig = {
            PathModified = "${cfg.stateDir}/.hermes";
            Unit = "hermes-shared-home.service";
          };
        };

        systemd.services.hermes-shared-home = {
          description = "Restore group access to HERMES_HOME";
          # Also on boot and on every activation, so a file broken while the
          # watcher was down is repaired without waiting for the next write.
          wantedBy = [ "multi-user.target" ];
          path = [
            pkgs.coreutils
            pkgs.findutils
          ];

          serviceConfig = {
            Type = "oneshot";
            ExecStart = toString (
              pkgs.writeShellScript "hermes-shared-home" ''
                set -uo pipefail
                d=${lib.escapeShellArg "${cfg.stateDir}/.hermes"}
                [ -d "$d" ] || exit 0
                # Regular files only: gateway.sock keeps its mode, and the
                # subdirectories are already handled by upstream's activation.
                find "$d" -maxdepth 1 -type f -print0 \
                  | xargs -0 -r chown ${config.services.hermes-agent.user}:${config.services.hermes-agent.group}
                find "$d" -maxdepth 1 -type f -print0 \
                  | xargs -0 -r chmod g+rw
                exit 0
              ''
            );
          };
        };
      })

      (lib.mkIf (sopsEnabled && cfg.secrets.envSecret != null) {
        sops.secrets.${cfg.secrets.envSecret} = {
          sopsFile = lib.mkIf (cfg.secrets.sopsFile != null) cfg.secrets.sopsFile;
        };
      })

      (lib.mkIf (sopsEnabled && cfg.backend.sessionTokenSecret != null) {
        sops.secrets.${cfg.backend.sessionTokenSecret} = {
          mode = "0400";
          sopsFile = lib.mkIf (cfg.secrets.sopsFile != null) cfg.secrets.sopsFile;
        };
      })

      (lib.mkIf (cfg.backend.mode != "none" && cfg.backend.openFirewall) {
        networking.firewall.allowedTCPPorts = [ cfg.backend.port ];
      })
    ]
  );
}
