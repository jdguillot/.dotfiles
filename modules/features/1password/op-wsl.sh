#!/bin/bash

# Find Windows User
WIN_PROFILE=$(cmd.exe /c "<nul set /p=%UserProfile%" 2>/dev/null)

# Find base folder for 1Password CLI in current user's Windows WinGet Packages
WIN_OP_BASE="$(wslpath $WIN_PROFILE)/AppData/Local/Microsoft/WinGet/Packages"

# Find the latest folder matching the pattern (AgileBits.1Password.CLI*)
OP_DIR=$(ls -td "$WIN_OP_BASE"/AgileBits.1Password.CLI* 2>/dev/null | head -n1)

if [ -z "$OP_DIR" ]; then
  echo "[ERROR] Could not find 1Password CLI folder in $WIN_OP_BASE" >&2
  exit 1
fi

# Export all OP_* environment variables to Windows
mapfile -d '' op_env_vars < <(env -0 | grep -z ^OP_ | cut -z -d= -f1)
if [ ${#op_env_vars[@]} -gt 0 ]; then
  export WSLENV="${WSLENV:-}:$(
    IFS=:
    echo "${op_env_vars[*]}"
  )"
fi

# If OP_ACCOUNT is set, pass it via --account flag
if [ -n "$OP_ACCOUNT" ]; then
  exec $OP_DIR/op.exe --account "$OP_ACCOUNT" "$@"
else
  exec $OP_DIR/op.exe "$@"
fi
