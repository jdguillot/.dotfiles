# Centralized per-host metadata. The attribute name, `system.hostname` and the
# directory under hosts/ holding the host's configuration.nix are all the same
# string -- flake.nix and .nixd-hosts.json both rely on that.
# `traits` (optional) names what the host is for; modules/core/traits
# turns each entry into cyberfighter.traits.<name> on both the system
# and home side.
# `home` is the folder under home/ providing the host's Home Manager config
# (null = no home configuration). `deploy` is null (not remotely deployable),
# "system", or "system+home". flake.nix derives nixosConfigurations,
# homeConfigurations, and deploy.nodes from these fields -- registering a
# host here is the only registration step.
let
  hosts = {
    razer-nixos = {
      profile = "desktop";
      traits = [ "dev" ];
      home = "cyberfighter";
      deploy = null;
      system = {
        hostname = "razer-nixos";
        username = "cyberfighter";
        # NixOS + home-manager were installed together on this host, so the
        # system and home stateVersion share this single per-host value.
        stateVersion = "25.05";
      };
    };

    work-nix-wsl = {
      profile = "wsl";
      traits = [ "dev" ];
      home = "jdguillot";
      deploy = null;
      system = {
        hostname = "work-nix-wsl";
        username = "jdguillot";
        stateVersion = "25.05";
      };
    };

    sys-galp-nix = {
      profile = "desktop";
      home = "cyberfighter";
      deploy = "system+home";
      system = {
        hostname = "sys-galp-nix";
        username = "cyberfighter";
        stateVersion = "24.11";
      };
    };

    thkpd-pve1 = {
      profile = "minimal";
      home = "cyberfighter";
      deploy = "system+home";
      system = {
        hostname = "thkpd-pve1";
        username = "cyberfighter";
        stateVersion = "25.11";
      };
    };

    simple-vm = {
      profile = "minimal";
      home = "cyberfighter";
      deploy = "system";
      system = {
        hostname = "simple-vm";
        username = "cyberfighter";
        stateVersion = "25.11";
      };
    };

    vm-gameserver-nix = {
      profile = "minimal";
      home = "minimal";
      deploy = "system+home";
      system = {
        hostname = "vm-gameserver-nix";
        username = "cyberfighter";
        stateVersion = "25.11";
      };
    };

    ryzn-server = {
      profile = "desktop";
      traits = [ "dev" ];
      home = "cyberfighter";
      deploy = "system+home";
      system = {
        hostname = "ryzn-server";
        username = "cyberfighter";
        stateVersion = "26.11";
      };
    };
  };
in
# homeConfigName is the single definition of the home-manager target naming
# convention; flake.nix and .nixd-hosts.json both read it instead of
# re-deriving "user@host" themselves.
builtins.mapAttrs (
  name: meta:
  meta
  // {
    homeConfigName = if meta.home != null then "${meta.system.username}@${name}" else null;
  }
) hosts
