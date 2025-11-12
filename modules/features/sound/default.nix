{
  config,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.features.sound;
in
{
  options.cyberfighter.features.sound = {
    enable = lib.mkEnableOption "Sound support with PipeWire";
  };

  config = lib.mkIf cfg.enable {
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };
}
