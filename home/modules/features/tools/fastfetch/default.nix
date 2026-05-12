{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.tools.fastfetch;
  
  dadjokeLogo = pkgs.writeShellScript "dadjoke-logo" ''
    # Get the joke
    joke=$(${pkgs.curl}/bin/curl -s --max-time 2 -H "Accept: text/plain" https://icanhazdadjoke.com 2>/dev/null || echo "No joke today!")
    
    # Wrap the joke to 20 characters, then pipe to cowsay
    wrapped_joke=$(echo "$joke" | ${pkgs.coreutils}/bin/fold -s -w 20)
    
    # Generate cowsay output with blue color from the terminal theme
    # ANSI color codes: \e[34m = blue (adapts to user's terminal theme), \e[0m = reset
    echo "$wrapped_joke" | ${pkgs.cowsay}/bin/cowsay -f sus -W 20 | ${pkgs.gnused}/bin/sed 's/^/\x1b[34m/' | ${pkgs.gnused}/bin/sed 's/$/\x1b[0m/'
  '';
  
  fastfetchWrapper = pkgs.writeShellScriptBin "fastfetch" ''
    # Generate the dadjoke logo to a file before running fastfetch
    ${dadjokeLogo} > ~/.config/fastfetch/dadjoke-logo.txt
    
    # Run fastfetch
    ${pkgs.fastfetch}/bin/fastfetch "$@"
  '';
in
{
  options.cyberfighter.features.tools.fastfetch = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "FastFetch - A fast and highly customizable system information tool";
    };
  };

  config = lib.mkIf cfg.enable {

    home.packages = [
      fastfetchWrapper
    ];

    xdg.configFile."fastfetch/config.jsonc".source = ./config.jsonc;
  };
}
