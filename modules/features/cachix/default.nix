{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.cachix;
in
{
  options.cyberfighter.features.cachix = {
    enable = lib.mkEnableOption "Enable devenv cachix substituter";
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.cyberfighter.features.sops.enable or false;
        message = "Cachix requires SOPS to be enabled for managing credentials";
      }
    ];

    environment.systemPackages = with pkgs; [
      cachix
    ];

    sops.secrets."cachix-auth-token" = {
      owner = "${config.cyberfighter.system.username}";
    };

    environment.shellInit = ''
      export CACHIX_AUTH_TOKEN=$(cat ${config.sops.secrets."cachix-auth-token".path})
    '';

  };
}
