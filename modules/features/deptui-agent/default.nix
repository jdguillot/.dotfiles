# deptui-agent -- unattended deploy-rs runner (github:jdguillot/deptui).
# Thin `cyberfighter.features.deptui-agent` wrapper around the upstream
# module (`inputs.deptui.nixosModules.deptui-agent`): watches/settings pass
# straight through; secrets enter by sops name and reach the daemon as file
# paths, never through the store.
#
# The agent needs its own ssh identity on every target: the public half is
# in `cyberfighter.features.ssh.authorizedKeys`, and targets already allow
# non-interactive sudo for wheel, which unattended activation requires.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.cyberfighter.features.deptui-agent;
  sopsEnabled = config.cyberfighter.features.sops.enable or false;
  settingsFormat = pkgs.formats.toml { };
in
{
  imports = [ inputs.deptui.nixosModules.deptui-agent ];

  options.cyberfighter.features.deptui-agent = {
    enable = lib.mkEnableOption "deptui-agent, the deploy-rs auto-deploy daemon";

    watches = lib.mkOption {
      type = lib.types.attrsOf settingsFormat.type;
      default = { };
      example = lib.literalExpression ''
        {
          dotfiles = {
            repo = "https://github.com/jdguillot/.dotfiles";
            branch = "main";
            interval = "15m";
            hosts.thkpd-pve1 = { };
          };
        }
      '';
      description = ''
        Watched repositories, passed to `services.deptui-agent.watches`.
        Host keys must match node names in this flake's `deploy.nodes`;
        per-host flags follow the agent's TOML schema (profile, mode,
        skip_checks, ssh.extra_opts, ...).
      '';
    };

    settings = lib.mkOption {
      type = settingsFormat.type;
      default = { };
      description = ''
        Freeform agent config merged over what the upstream module
        generates -- notification hooks (`notify.*`) go here.
      '';
    };

    listen = {
      enable = lib.mkEnableOption "the token-gated TCP kick/status listener for CI";

      address = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0";
        description = "Address the kick/status listener binds.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 7337;
        description = "Port of the kick/status listener.";
      };
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the listener's port. Worst-case token leak triggers a poll of an already-trusted repo, nothing more.";
    };

    secrets = {
      sshKey = lib.mkOption {
        type = lib.types.str;
        default = "deptui-agent-ssh-key";
        description = ''
          Sops secret holding the agent's private ssh key (targets and
          private repos). The module declares the secret, owned by the
          agent's service user.
        '';
      };

      listenToken = lib.mkOption {
        type = lib.types.str;
        default = "deptui-agent-listen-token";
        description = ''
          Sops secret holding the bearer token the TCP listener requires.
          Only declared when `listen.enable` is set. Callers kick with
          `curl -H "Authorization: Bearer $(sops -d --extract
          '["deptui-agent-listen-token"]' secrets/secrets.yaml)"`.
        '';
      };
    };

    groupMembers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "cyberfighter" ];
      description = ''
        Users added to the agent's group. The control socket is group
        0660, so membership is what lets `deptui-agent status`/`kick`
        (and the deptui TUI over ssh) talk to the daemon without sudo.
      '';
    };

    addToSystemPackages = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install the deptui-agent binary; its CLI verbs double as the local and over-ssh control interface.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = sopsEnabled;
        message = "cyberfighter.features.deptui-agent needs cyberfighter.features.sops.enable = true for its key and token secrets.";
      }
    ];

    sops.secrets =
      {
        ${cfg.secrets.sshKey} = {
          owner = config.services.deptui-agent.user;
          mode = "0400";
          restartUnits = [ "deptui-agent.service" ];
        };
      }
      // lib.optionalAttrs cfg.listen.enable {
        ${cfg.secrets.listenToken} = {
          owner = config.services.deptui-agent.user;
          mode = "0400";
          restartUnits = [ "deptui-agent.service" ];
        };
      };

    services.deptui-agent = {
      enable = true;
      watches = cfg.watches;
      settings = cfg.settings;
      sshKeyFile = config.sops.secrets.${cfg.secrets.sshKey}.path;
      openFirewall = cfg.openFirewall;

      listen = lib.mkIf cfg.listen.enable {
        enable = true;
        address = cfg.listen.address;
        port = cfg.listen.port;
        tokenFile = config.sops.secrets.${cfg.secrets.listenToken}.path;
      };
    };

    users.users = lib.genAttrs cfg.groupMembers (_: {
      extraGroups = [ config.services.deptui-agent.group ];
    });

    environment.systemPackages = lib.optional cfg.addToSystemPackages config.services.deptui-agent.package;
  };
}
