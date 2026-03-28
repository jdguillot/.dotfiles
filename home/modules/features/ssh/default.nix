{
  config,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.features.ssh;
  onepassConfig = ''
    IdentityAgent ~/.1password/agent.sock
  '';
  secretsFile = ./ssh-hosts.yaml;
  hostsAvailable = cfg.hosts != [ ] && builtins.pathExists secretsFile;
  templateName = "ssh-hosts-config";
in
{
  options.cyberfighter.features.ssh = {
    enable = lib.mkEnableOption "SSH Client";
    onepass = lib.mkEnableOption "Enable 1Password SSH Integration";

    extraConfig = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Extra SSH global config options";
    };

    hosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Host aliases to load from the shared ssh-hosts.yaml secrets file, in order.
        Each alias must be a top-level key in that file whose value is a block of
        SSH directives as a multiline string, e.g.:
          my-server: |
            HostName 192.168.1.100
            User alice
            IdentityFile ~/.ssh/id_ed25519
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        programs.ssh = {
          enable = true;
          enableDefaultConfig = false;
          extraConfig = (if cfg.onepass then onepassConfig else "") + cfg.extraConfig;
          matchBlocks."*" = {
            forwardAgent = false;
            addKeysToAgent = "no";
            compression = false;
            serverAliveInterval = 0;
            serverAliveCountMax = 3;
            hashKnownHosts = false;
            userKnownHostsFile = "~/.ssh/known_hosts";
            controlMaster = "no";
            controlPath = "~/.ssh/master-%r@%n:%p";
            controlPersist = "no";
          };
        };
      }

      (lib.mkIf hostsAvailable {
        sops.secrets = lib.listToAttrs (
          map (alias: {
            name = alias;
            value = {
              sopsFile = secretsFile;
            };
          }) cfg.hosts
        );

        sops.templates.${templateName}.content = lib.concatMapStrings (
          alias: "Host ${alias}\n${config.sops.placeholder.${alias}}\n"
        ) cfg.hosts;

        programs.ssh.extraConfig = ''
          Include ${config.sops.templates.${templateName}.path}
        '';
      })
    ]
  );
}
