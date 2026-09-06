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
# `system.hostKey` (optional) is the host's ed25519 PUBLIC host key -- just
# the "ssh-ed25519 AAAA..." part, WITHOUT the leading hostname ssh-keyscan
# prints (hostNames come from the attr name). modules/core/known-hosts pins
# every non-null entry into programs.ssh.knownHosts fleet-wide. Filling it
# is OPTIONAL hardening (deptui-agent trusts-and-pins on first contact by
# itself) with one exception: a host used as a REMOTE BUILDER must be
# pinned -- the nix-daemon's batch-mode ssh cannot do trust-on-first-use,
# and without a pin remote builds silently fall back to local. That is why
# ryzn-server's key stays filled (razer builds through it).
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
        hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFyQFHfTKerpKsleyzakegpS+q8jAbekdvE9GvLpMTcg";
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
        hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILJF1qfm012fP6lTXrEA54zyK1+iYVEirdySFIe6L99l";
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
