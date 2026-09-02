{

  description = "My First Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";

    # Home-manager using the same nixpkgs
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs"; # Follow the same nixpkgs version
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    vscode-server.url = "github:nix-community/nixos-vscode-server";

    anthropic-skills = {
      url = "github:anthropics/skills";
      flake = false;
    };

    # Skill registry (rust-best-practices, tauri-v2, golang-* skills).
    autoskills = {
      url = "github:midudev/autoskills";
      flake = false;
    };

    # Nix flake conventions skill (nix-flakes).
    nix-skills = {
      url = "github:nhooey/nix-skills";
      flake = false;
    };

    catppuccin.url = "github:catppuccin/nix";
    proxmox-nixos.url = "github:SaumonNet/proxmox-nixos";
    #    pst-bin.url = "path:./programs/pst";
    #    tasmotizer.url = "path:./programs/tasmotizer";
    deploy-rs.url = "github:serokell/deploy-rs";
    deptui.url = "github:jdguillot/deptui";
    niri.url = "github:sodiboo/niri-flake";
    noctalia = {
      url = "github:noctalia-dev/noctalia/legacy-v4";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hermes Agent (Nous Research). Deliberately not `follows`-ing nixpkgs:
    # the module builds its package from its own uv2nix/pyproject-nix lock
    # against its own pinned nixpkgs, and repointing it invites build breakage.
    hermes-agent.url = "github:NousResearch/hermes-agent";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nix-flatpak,
      nixpkgs-stable,
      sops-nix,
      disko,
      catppuccin,
      proxmox-nixos,
      deploy-rs,
      niri,
      noctalia,
      lanzaboote,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs-stable = import nixpkgs-stable { inherit system; };

      # Unmodified nixpkgs packages (used to force deploy-rs binary from nixpkgs cache)
      pkgs = nixpkgs.legacyPackages.${system};
      # nixpkgs with deploy-rs overlay, but binary forced from nixpkgs for cache hits
      deployPkgs = import nixpkgs {
        inherit system;
        overlays = [
          deploy-rs.overlays.default
          (_: super: {
            deploy-rs = {
              inherit (pkgs) deploy-rs;
              lib = super.deploy-rs.lib;
            };
          })
        ];
      };

      # Import centralized host metadata
      hostConfigs = import ./hosts/default.nix;

      # Shared special args
      sharedSpecialArgs = hostMeta: {
        inherit
          inputs
          pkgs-stable
          hostMeta
          ;
        hostSystem = system;
        hostProfile = hostMeta.profile;
      };

      # Helper function to create NixOS system configuration
      mkNixosSystem =
        hostMeta:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = (sharedSpecialArgs hostMeta) // {
            inherit proxmox-nixos;
          };
          modules = [
            ./hosts/${hostMeta.system.hostname}/configuration.nix
            sops-nix.nixosModules.sops
            disko.nixosModules.disko
            catppuccin.nixosModules.catppuccin
            # Imported for every host: boot.lanzaboote.* is referenced under
            # mkIf, and options must exist even when the condition is false.
            lanzaboote.nixosModules.lanzaboote
            proxmox-nixos.nixosModules.proxmox-ve
            {
              nixpkgs.overlays = [
                niri.overlays.niri
              ];
              # Themed per-user via home-manager; explicit opt-out silences
              # the auto-enroll eval warning.
              catppuccin.autoEnable = false;
            }
          ];
        };

      # Helper function to create home-manager configuration
      mkHomeConfig =
        homeFolder: hostMeta:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = sharedSpecialArgs hostMeta;
          modules = [
            ./home/${homeFolder}/home.nix
            nix-flatpak.homeManagerModules.nix-flatpak
            catppuccin.homeModules.catppuccin
            sops-nix.homeManagerModules.sops
            niri.homeModules.config
            noctalia.homeModules.default
          ];
        };

      # Helper function to create a deploy-rs node configuration
      mkDeployNode =
        hostname: hostMeta: withHome:
        let
          username = hostMeta.system.username;
        in
        {
          inherit hostname;
          # The host's own user, never root: the home profile needs a real
          # login session (`sudo -u` from root has no D-Bus, so
          # `systemctl --user` fails).
          sshUser = username;
        }
        // (
          if withHome then
            {
              profilesOrder = [
                "system"
                "home"
              ];
            }
          else
            { }
        )
        // {
          profiles = {
            system = {
              user = "root";
              path = deployPkgs.deploy-rs.lib.activate.nixos self.nixosConfigurations.${hostname};
            };
          }
          // (
            if withHome then
              {
                home = {
                  user = username;
                  path =
                    deployPkgs.deploy-rs.lib.activate.home-manager
                      self.homeConfigurations."${username}@${hostname}";
                };
              }
            else
              { }
          );
        };

    in
    {
      nixosConfigurations = {
        razer-nixos = mkNixosSystem hostConfigs.razer-nixos;
        work-nix-wsl = mkNixosSystem hostConfigs.work-nix-wsl;
        sys-galp-nix = mkNixosSystem hostConfigs.sys-galp-nix;
        thkpd-pve1 = mkNixosSystem hostConfigs.thkpd-pve1;
        simple-vm = mkNixosSystem hostConfigs.simple-vm;
        vm-gameserver-nix = mkNixosSystem hostConfigs.vm-gameserver-nix;
        ryzn-server = mkNixosSystem hostConfigs.ryzn-server;
      };

      homeConfigurations = {
        "cyberfighter@razer-nixos" = mkHomeConfig "cyberfighter" hostConfigs.razer-nixos;
        "jdguillot@work-nix-wsl" = mkHomeConfig "jdguillot" hostConfigs.work-nix-wsl;
        "cyberfighter@sys-galp-nix" = mkHomeConfig "cyberfighter" hostConfigs.sys-galp-nix;
        "cyberfighter@thkpd-pve1" = mkHomeConfig "cyberfighter" hostConfigs.thkpd-pve1;
        "cyberfighter@simple-vm" = mkHomeConfig "cyberfighter" hostConfigs.simple-vm;
        "cyberfighter@vm-gameserver-nix" = mkHomeConfig "minimal" hostConfigs.vm-gameserver-nix;
        "cyberfighter@ryzn-server" = mkHomeConfig "cyberfighter" hostConfigs.ryzn-server;
      };

      deploy.nodes = {
        thkpd-pve1 = mkDeployNode "thkpd-pve1" hostConfigs.thkpd-pve1 true;
        simple-vm = mkDeployNode "simple-vm" hostConfigs.simple-vm false;
        vm-gameserver-nix = mkDeployNode "vm-gameserver-nix" hostConfigs.vm-gameserver-nix true;
        sys-galp-nix = mkDeployNode "sys-galp-nix" hostConfigs.sys-galp-nix true;
        ryzn-server = mkDeployNode "ryzn-server" hostConfigs.ryzn-server true;
      };

      # This is highly advised, and will prevent many possible mistakes
      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

    };

}
