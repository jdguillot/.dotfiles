# deptui-agent -- unattended deploy-rs runner (github:jdguillot/deptui).
# Thin `cyberfighter.features.deptui-agent` wrapper around the upstream
# module (`inputs.deptui.nixosModules.deptui-agent`): watches/settings pass
# straight through.
#
# Identity: the agent GENERATES its own ed25519 key on first start (the
# upstream default) -- the private half never leaves the host, so there is
# no ssh secret to manage. Read the public half with `deptui-agent pubkey`
# and keep it in `cyberfighter.features.ssh` standardAuthorizedKeys; targets
# already allow non-interactive sudo for wheel, which unattended activation
# requires. Sops secrets: the optional TCP listener token, and the git-crypt
# key for watches that set `git_crypt_key_file`.
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
  gitCryptPaths = lib.unique (lib.catAttrs "git_crypt_key_file" (lib.attrValues cfg.watches));
  gitCryptEnabled = gitCryptPaths != [ ];
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
            interval = "15m"; # or cron = "0 */6 * * *"
            git_crypt_key_file = config.cyberfighter.features.deptui-agent.gitCryptKeyFile;
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

    # Not under /run/deptui-agent: that is the unit's RuntimeDirectory and
    # systemd removes it on every stop.
    gitCryptKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/deptui-agent-git-crypt/key";
      description = ''
        Where the decoded git-crypt key is installed for the agent user.
        Watches of git-crypt repos set `git_crypt_key_file` to this value;
        the module refuses any other path so the secret and the watch
        cannot drift apart.
      '';
    };

    secrets = {
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
      gitCryptKey = lib.mkOption {
        type = lib.types.str;
        default = "git-crypt-key";
        description = ''
          Sops secret holding the exported git-crypt key, base64-encoded
          (`git-crypt export-key - | base64 -w0`). Declared, decoded and
          installed at `gitCryptKeyFile` only when a watch sets
          `git_crypt_key_file`.
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
        assertion = cfg.listen.enable -> sopsEnabled;
        message = "cyberfighter.features.deptui-agent.listen needs cyberfighter.features.sops.enable = true for the listener token secret.";
      }
      {
        assertion = gitCryptEnabled -> sopsEnabled;
        message = "cyberfighter.features.deptui-agent: a watch sets git_crypt_key_file, which needs cyberfighter.features.sops.enable = true for the git-crypt key secret.";
      }
      {
        assertion = gitCryptPaths == [ ] || gitCryptPaths == [ cfg.gitCryptKeyFile ];
        message = "cyberfighter.features.deptui-agent: every watch's git_crypt_key_file must equal gitCryptKeyFile (${cfg.gitCryptKeyFile}); got ${lib.concatStringsSep ", " gitCryptPaths}.";
      }
    ];

    sops.secrets =
      lib.optionalAttrs cfg.listen.enable {
        ${cfg.secrets.listenToken} = {
          owner = config.services.deptui-agent.user;
          mode = "0400";
          restartUnits = [ "deptui-agent.service" ];
        };
      }
      # Root-owned base64 form; only the decoded copy below is the agent's.
      // lib.optionalAttrs gitCryptEnabled {
        ${cfg.secrets.gitCryptKey} = {
          mode = "0400";
        };
      };

    # Decoded outside /run/secrets, which sops-nix rebuilds each switch.
    # -i: whitespace where base64 wrapped lines would otherwise stop the
    # decode early and leave a truncated key behind.
    system.activationScripts.deptuiGitCryptKey = lib.mkIf gitCryptEnabled (
      lib.stringAfter [ "setupSecrets" ] ''
        install -d -m 0755 ${builtins.dirOf cfg.gitCryptKeyFile}
        (umask 077; ${lib.getExe' pkgs.coreutils "base64"} -di ${
          config.sops.secrets.${cfg.secrets.gitCryptKey}.path
        } > ${cfg.gitCryptKeyFile}.tmp) \
          && install -o ${config.services.deptui-agent.user} -m 0400 ${cfg.gitCryptKeyFile}.tmp ${cfg.gitCryptKeyFile}
        rm -f ${cfg.gitCryptKeyFile}.tmp
      ''
    );

    services.deptui-agent = {
      enable = true;
      watches = cfg.watches;
      settings = cfg.settings;
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
