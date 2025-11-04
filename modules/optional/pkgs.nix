{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    nodejs
    nil
    esphome
    platformio
  ];
}
