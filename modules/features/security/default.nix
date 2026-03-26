{
  config,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.features.security;
in
{
  options.cyberfighter.features.security = {
    firejail = lib.mkEnableOption "Firejail application sandboxing";
  };

  config = lib.mkIf cfg.firejail {
    programs.firejail.enable = true;
  };
}
