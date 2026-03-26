{
  config,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.features.printing;
in
{
  options.cyberfighter.features.printing = {
    enable = lib.mkEnableOption "CUPS printing support";
  };

  config = lib.mkIf cfg.enable {
    services.printing.enable = true;
  };
}
