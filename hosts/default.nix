# Centralized per-host metadata. The attribute name, `system.hostname` and the
# directory under hosts/ holding the host's configuration.nix are all the same
# string -- flake.nix and .nixd-hosts.json both rely on that.
# `traits` (optional) names what the host is for; modules/core/traits
# turns each entry into cyberfighter.traits.<name> on both the system
# and home side.
{
  razer-nixos = {
    profile = "desktop";
    traits = [ "dev" ];
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
    system = {
      hostname = "work-nix-wsl";
      username = "jdguillot";
      stateVersion = "25.05";
    };
  };

  sys-galp-nix = {
    profile = "desktop";
    system = {
      hostname = "sys-galp-nix";
      username = "cyberfighter";
      stateVersion = "24.11";
    };
  };

  thkpd-pve1 = {
    profile = "minimal";
    system = {
      hostname = "thkpd-pve1";
      username = "cyberfighter";
      stateVersion = "25.11";
    };
  };

  simple-vm = {
    profile = "minimal";
    system = {
      hostname = "simple-vm";
      username = "cyberfighter";
      stateVersion = "25.11";
    };
  };

  vm-gameserver-nix = {
    profile = "minimal";
    system = {
      hostname = "vm-gameserver-nix";
      username = "cyberfighter";
      stateVersion = "25.11";
    };
  };

  ryzn-server = {
    profile = "desktop";
    traits = [ "dev" ];
    system = {
      hostname = "ryzn-server";
      username = "cyberfighter";
      stateVersion = "26.11";
    };
  };
}
