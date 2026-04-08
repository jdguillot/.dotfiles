{

  description = "My First Flake";

  inputs = {
    # # This is the long form of both of below
    nixpkgs.url = "nixpkgs/nixos-unstable";

    nixpkgs-stable.url = "nixpkgs/nixos-25.11";

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

    catppuccin.url = "github:catppuccin/nix";
    proxmox-nixos.url = "github:SaumonNet/proxmox-nixos";
    isd.url = "github:kainctl/isd";
    #    pst-bin.url = "path:./programs/pst";
    #    tasmotizer.url = "path:./programs/tasmotizer";
    deploy-rs.url = "github:serokell/deploy-rs";
    niri.url = "github:sodiboo/niri-flake";
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
        hostname: hostMeta:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = (sharedSpecialArgs hostMeta) // {
            inherit proxmox-nixos;
          };
          modules = [
            ./hosts/${hostname}/configuration.nix
            sops-nix.nixosModules.sops
            disko.nixosModules.disko
            catppuccin.nixosModules.catppuccin
            proxmox-nixos.nixosModules.proxmox-ve
            {
              nixpkgs.overlays = [
                niri.overlays.niri
              ];
            }
            noctalia.nixosModules.default
          ];
        };

      # Helper function to create home-manager configuration
      mkHomeConfig =
        hostname: hostMeta:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = sharedSpecialArgs hostMeta;
          modules = [
            ./home/${hostMeta.system.username}/home.nix
            nix-flatpak.homeManagerModules.nix-flatpak
            catppuccin.homeModules.catppuccin
            sops-nix.homeManagerModules.sops
            niri.homeModules.config
            noctalia.homeModules.default
          ]
          # ++ (if hostname == "razer-nixos" || hostname == "sys-galp-nix" then [ ] else [ ])
          ;
        };

      # Helper function to create a deploy-rs node configuration
      mkDeployNode =
        hostname: hostMeta: withHome:
        let
          username = hostMeta.system.username;
        in
        {
          inherit hostname;
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
        razer-nixos = mkNixosSystem "razer-nixos" hostConfigs.razer-nixos;
        work-nix-wsl = mkNixosSystem "work-wsl" hostConfigs.work-nix-wsl;
        ryzn-nix-wsl = mkNixosSystem "ryzn-wsl" hostConfigs.ryzn-nix-wsl;
        sys-galp-nix = mkNixosSystem "sys-galp-nix" hostConfigs.sys-galp-nix;
        nixos-portable = mkNixosSystem "nixos-portable" hostConfigs.nixos-portable;
        thkpd-pve1 = mkNixosSystem "thkpd-pve1" hostConfigs.thkpd-pve1;
        simple-vm = mkNixosSystem "simple-vm" hostConfigs.simple-vm;
        vm-gameserver-nix = mkNixosSystem "vm-gameserver-nix" hostConfigs.vm-gameserver-nix;
      };

      homeConfigurations = {
        "cyberfighter@razer-nixos" = mkHomeConfig "razer-nixos" hostConfigs.razer-nixos;
        "jdguillot@work-nix-wsl" = mkHomeConfig "work-nix-wsl" hostConfigs.work-nix-wsl;
        "cyberfighter@ryzn-nix-wsl" = mkHomeConfig "ryzn-nix-wsl" hostConfigs.ryzn-nix-wsl;
        "cyberfighter@sys-galp-nix" = mkHomeConfig "sys-galp-nix" hostConfigs.sys-galp-nix;
        "cyberfighter@thkpd-pve1" = mkHomeConfig "thkpd-pve1" hostConfigs.thkpd-pve1;
        "cyberfighter@simple-vm" = mkHomeConfig "simple-vm" hostConfigs.simple-vm;
      };

      deploy.nodes = {
        thkpd-pve1 = mkDeployNode "thkpd-pve1" hostConfigs.thkpd-pve1 true;
        simple-vm = mkDeployNode "simple-vm" hostConfigs.simple-vm false;
        vm-gameserver-nix = mkDeployNode "vm-gameserver-nix" hostConfigs.vm-gameserver-nix false;
        sys-galp-nix = mkDeployNode "sys-galp-nix" hostConfigs.sys-galp-nix true;
      };

      # This is highly advised, and will prevent many possible mistakes
      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

    };

}
