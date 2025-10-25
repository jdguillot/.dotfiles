{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    htop
    btop
    vim
    wget
    cifs-utils
    lshw
    pciutils
    git
    gh
    bitwarden-cli
    appimage-run
    xclip
  ];
}
