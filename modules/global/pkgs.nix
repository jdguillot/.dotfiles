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
    lazyjj
    bitwarden-cli
    appimage-run
    xclip
  ];
}
