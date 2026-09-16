# Banner-fronted rebuild/update helpers behind the ns, nb, hs, nu and np
# aliases. Each stage prints its own banner, so a two-stage run (system
# rebuild, then Home Manager) stays readable in scrollback.

dotfiles="${CF_DOTFILES:-$HOME/.dotfiles}"
host="$(uname -n)"
host="${host%%.*}"
target="$USER@$host"

# banner <color-256> <icon> <title> <detail>
banner() {
  local color="$1" icon="$2" title="$3" detail="$4"
  local width=72 bold="" dim="" accent="" reset="" pad rule cols

  # Colors and terminal width only when stdout is a terminal, so piped or
  # logged output stays plain.
  if [[ -t 1 ]]; then
    bold=$'\e[1m'
    dim=$'\e[2m'
    accent=$'\e[38;5;'"$color"'m'
    reset=$'\e[0m'
    cols="$(tput cols 2>/dev/null || echo 72)"
    if [[ "$cols" =~ ^[0-9]+$ ]] && ((cols < width)); then
      width="$cols"
    fi
  fi

  # printf pad + substitution repeats a multi-byte glyph without needing seq
  # or a character-width-correct ${#var}.
  printf -v pad '%*s' "$width" ""
  rule="${pad// /─}"

  printf '\n%s%s%s\n' "$accent" "$rule" "$reset"
  printf ' %s%s  %s%s\n' "$accent$bold" "$icon" "$title" "$reset"
  if [[ -n "$detail" ]]; then
    printf ' %s   %s%s\n' "$dim" "$detail" "$reset"
  fi
  printf '%s%s%s\n\n' "$accent" "$rule" "$reset"
}

home_switch() {
  banner 114 "⌂" "Home Manager · switch" \
    "target $target · flake $dotfiles#$target · $(date +%T)"
  home-manager switch --flake "$dotfiles#$target" "$@"
}

usage() {
  cat <<'USAGE'
Usage: cf-nix <command> [args...]

  switch   nixos-rebuild switch, then home-manager switch   (alias: ns)
  boot     nixos-rebuild boot, then home-manager switch     (alias: nb)
  home     home-manager switch only                         (alias: hs)
  update   nix flake update                                 (alias: nu)
  pins     npins update [name...]                           (alias: np)

Extra args are forwarded to the underlying command(s). The flake lives at
$CF_DOTFILES (default ~/.dotfiles).
USAGE
}

case "${1:-}" in
  switch | boot)
    mode="$1"
    shift
    banner 75 "❄" "NixOS rebuild · $mode" \
      "host $host · flake $dotfiles · $(date +%T)"
    sudo nixos-rebuild "$mode" --flake "$dotfiles" "$@"
    home_switch "$@"
    ;;
  home)
    shift
    home_switch "$@"
    ;;
  update)
    shift
    banner 179 "↻" "Flake update" \
      "$dotfiles/flake.lock · $(date +%T)"
    nix flake update --flake "$dotfiles" "$@"
    ;;
  pins)
    shift
    banner 176 "⚓" "npins update" \
      "${*:-all pins} · $dotfiles/npins/sources.json · $(date +%T)"
    npins -d "$dotfiles/npins" update "$@"
    ;;
  -h | --help | help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
