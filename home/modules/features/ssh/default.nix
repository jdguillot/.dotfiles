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
in
{
  options.cyberfighter.features.ssh = {
    enable = lib.mkEnableOption "SSH Client";
    onepass = lib.mkEnableOption "Enable 1Password SSH Integration";

    extraConfig = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Extra SSH Config options";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.ssh = {
      enable = true;
      extraConfig = (if cfg.onepass then onepassConfig else "") + cfg.extraConfig;
    };
  };
}
