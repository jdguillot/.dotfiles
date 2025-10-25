{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    vim
    wget
    cifs-utils
    lshw
    git
    gh
  ];
}
