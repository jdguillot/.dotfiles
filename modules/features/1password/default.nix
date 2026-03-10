{
  pkgs,
  ...
}:
let
  op-wsl = pkgs.writeShellScriptBin "op" (builtins.readFile ./op-wsl.sh);
in
{
  environment.systemPackages = [ op-wsl ];
}
