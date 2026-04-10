{ config, lib, ... }:

let
  cfg = config.cyberfighter.features.gameserver;
in
{
  imports = [
    ./astroneer
    ./playit
  ];

  options.cyberfighter.features.gameserver = {
    enable = lib.mkEnableOption "Game server host infrastructure";
  };

  # Gate all sub-modules behind the top-level enable flag
  config = lib.mkIf cfg.enable { };
}
