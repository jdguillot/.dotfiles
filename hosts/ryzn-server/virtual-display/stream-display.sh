# Swap the Plasma session between the physical monitor(s) and the virtual 4K
# output (an EDID-forced HDMI connector), so games and captures land on it.
#
#   stream-display on [WxH@Hz]   virtual output only
#   stream-display off           every other connected output, virtual off
#   stream-display status
#
# `on` without a mode takes the first of $MODES the output offers. The
# Moonlight client's mode is ignored: Sunshine scales to it when encoding.

virtual=$VIRTUAL_OUTPUT

# Sunshine starts before Plasma, so its hooks inherit no WAYLAND_DISPLAY.
if [[ -z ${WAYLAND_DISPLAY:-} ]]; then
  for sock in "$XDG_RUNTIME_DIR"/wayland-[0-9]; do
    [[ -S $sock ]] && export WAYLAND_DISPLAY=${sock##*/} && break
  done
fi

state=$(kscreen-doctor -j)
others=$(jq -r --arg v "$virtual" '.outputs[] | select(.connected and .name != $v) | .name' <<<"$state")

# Mode id on the virtual output for WxH@Hz (refresh rounded), or nothing.
# kscreen-doctor exits 0 on a mode it rejects, so it is checked here.
mode_id() {
  [[ $1 =~ ^[0-9]+x[0-9]+@[0-9]+$ ]] || return 0
  local w=${1%%x*} rest=${1#*x}
  local h=${rest%@*} hz=${rest#*@}
  jq -r --arg v "$virtual" --argjson w "$w" --argjson h "$h" --argjson hz "$hz" '
    .outputs[] | select(.name == $v) | .modes[]
    | select(.size.width == $w and .size.height == $h and (.refreshRate | round) == $hz)
    | .id' <<<"$state" | head -n1
}

case "${1:-status}" in
  on)
    read -ra modes <<<"$MODES"
    if [[ -n ${2:-} ]]; then
      modes=("$2" "${modes[@]}")
    fi
    id=
    for mode in "${modes[@]}"; do
      id=$(mode_id "$mode")
      [[ -n $id ]] && break
    done
    if [[ -z $id ]]; then
      echo "stream-display: $virtual offers none of: ${modes[*]}" >&2
      exit 1
    fi
    # Origin at 0,0: Sunshine maps absolute input (touch, pen, a VR laser)
    # from offset 0, but KWin keeps the slot it had beside the monitor.
    args=("output.$virtual.enable" "output.$virtual.mode.$id" "output.$virtual.priority.1"
      "output.$virtual.position.0,0")
    for o in $others; do args+=("output.$o.disable"); done
    kscreen-doctor "${args[@]}"
    ;;
  off)
    args=()
    for o in $others; do args+=("output.$o.enable"); done
    args+=("output.$virtual.disable")
    kscreen-doctor "${args[@]}"
    ;;
  status)
    kscreen-doctor -o
    ;;
  *)
    echo "usage: stream-display on [WxH@Hz] | off | status" >&2
    exit 2
    ;;
esac
