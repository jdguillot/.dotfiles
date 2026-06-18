{
  razer-nixos = {
    profile = "desktop";
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
    system = {
      hostname = "work-nix-wsl";
      username = "jdguillot";
      stateVersion = "25.05";
    };
  };

  ryzn-nix-wsl = {
    profile = "wsl";
    system = {
      hostname = "ryzn-nix-wsl";
      username = "cyberfighter";
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

  nixos-portable = {
    profile = "desktop";
    system = {
      hostname = "nixos-portable";
      username = "cyberfighter";
      stateVersion = "25.05";
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
}
