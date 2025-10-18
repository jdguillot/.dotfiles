{ pkgs, inputs, ... }:
{
  environment.systemPackages = with pkgs; [
    appimage-run
    xclip
    inputs.nixos-conf-editor.packages.${system}.nixos-conf-editor
    nodejs
    vulkan-tools
    vulkan-loader
    virtualgl
    nil
  ];
}
