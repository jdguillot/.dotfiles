# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

# NixOS-WSL specific options are documented on the NixOS-WSL repository:
# https://github.com/nix-community/NixOS-WSL

{ config, lib, pkgs, inputs, ... }:

{
 imports = [
    ./docker-desktop-fix.nix
 ];

  wsl.docker-desktop.enable = true;
  fix.docker-desktop.enable = true;

  users.users."jdguillot" = {
  	extraGroups = [
		"wheel"
  		"docker"
  	];
  };

  programs.nix-ld = {
    enable = true;
    package = pkgs.nix-ld-rs;
  };

  # programs.vscode = {
  #   extensions = with pkgs.vscode-extensions; [
  #     bbenoist.nix
  #     ms-python.python
  #     ms-azuretools.vscode-docker
  #     ms-vscode-remote.remote-ssh
  #     ms-vscode-remote.remote-containers
  #     esbenp.prettier-vscode
  #     ritwickdey.liveserver
  #     eamodio.gitlens
  #     visualstudioexptteam.intellicode-api-usage-examples
  #     github.vscode-pull-request-github
  #     redhat.vscode-yaml
  #     yzhang.markdown-all-in-one
  #     mhutchie.git-graph
  #     zhuangtongfa.material-theme
  #   ]; 
  # };

  nixpkgs.config = {
    allowUnfree = true;
  };

  services.vscode-server.enable = true;

  # system.activationScripts = {
  #   # symlink nixOS extensions to trick vscode into thinking they are installed
  #   fixVsCodeExtensions = {
  #     text = ''
  #       EXT_DIR=/home/jdguillot/.vscode-server/extensions
  #       mkdir -p $EXT_DIR
  #       chown jdguillot:users $EXT_DIR
  #       ln -sf /home/jdguillot/.vscode/extensions/* $EXT_DIR/
  #       done
  #       chown -R jdguillot:users $EXT_DIR
  #     '';
  #     deps = [ ];
  #   };
  # };
  
  

  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    cifs-utils
    appimage-run
    xclip
    inputs.nixos-conf-editor.packages.${system}.nixos-conf-editor
#     fishPlugins.done
#     fishPlugins.fzf-fish
#     fishPlugins.forgit
# #    fishPlugins.hydro
#     fzf
#     fishPlugins.grc
    grc  
    nodejs
    # wineWowPackages.stable
    # vscode
    
  ];
  

  # virtualisation.docker = {
  #   enable = true;
  #   enableOnBoot = true;
  #   autoPrune.enable = true;
  # };

  # services.vscode-server = {
  #   enable = true;   
  # };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
    # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
