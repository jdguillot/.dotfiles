#!/usr/bin/env bash

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Provision a NixOS host using nixos-anywhere with 1Password-managed SSH keys.

Options:
  -n, --hostname NAME        Hostname for the NixOS configuration
  -t, --target TARGET        Target in the form user@host (may include -p port)
  -c, --hardware-config      Generate hardware-configuration.nix
      --no-hardware-config   Skip generating hardware-configuration.nix
  -s, --secrets              Add this host to the secrets/sops config
      --no-secrets           Skip secrets setup
  -h, --help                 Show this help message and exit

If options are not provided, the script will prompt interactively.
EOF
}

copy() {
  if command -v wl-copy >/dev/null 2>&1; then
    wl-copy
  elif command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard
  elif command -v xsel >/dev/null 2>&1; then
    xsel --clipboard --input
  elif command -v pbcopy >/dev/null 2>&1; then
    pbcopy
  elif command -v clip.exe >/dev/null 2>&1; then
    clip.exe
  else
    echo "No clipboard utility found" >&2
    return 1
  fi
}

HOSTNAME=""
TARGET=()
HARDCONFIG=""
SECRETS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--hostname)
      HOSTNAME="$2"
      shift 2
      ;;
    -t|--target)
      shift
      while [[ $# -gt 0 && ! "$1" =~ ^- || "$1" == "-p" ]]; do
        TARGET+=("$1")
        shift
      done
      ;;
    -c|--hardware-config)
      HARDCONFIG="Y"
      shift
      ;;
    --no-hardware-config)
      HARDCONFIG="n"
      shift
      ;;
    -s|--secrets)
      SECRETS="y"
      shift
      ;;
    --no-secrets)
      SECRETS="N"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# Prompt for any values not provided via arguments
[[ -z "$HOSTNAME" ]] && read -p "What is the hostname: " HOSTNAME
[[ ${#TARGET[@]} -eq 0 ]] && read -p "What is the target. user@host -p port: " -a TARGET
[[ -z "$HARDCONFIG" ]] && read -p "Do you want to create a hardware-configuration.nix? [Y/n]: " HARDCONFIG
[[ -z "$SECRETS" ]] && read -p "Should this host be able to access secrets? [y/N]: " SECRETS

if [[ ! $HARDCONFIG =~ ^[Nn]$ ]]; then
  GENHARD=(--generate-hardware-config nixos-generate-config ./hosts/$HOSTNAME/hardware-configuration.nix)
else
  GENHARD=()
fi


# Create a temporary directory
temp=$(mktemp -d)

# Function to cleanup temporary directory on exit
cleanup() {
  rm -rf "$temp"
}
trap cleanup EXIT

# Create the directory where sshd expects to find the host keys
install -d -m755 "$temp/etc/ssh"

# Decrypt your private key from the password store and copy it to the temporary directory
op item get $HOSTNAME --vault='Dev' || { read -p "Do you want to create a key for ${HOSTNAME}? [y/N]: " CREATE_KEY; if [[ $CREATE_KEY =~ ^[Yy]$ ]]; then op item create --category ssh-key --title=${HOSTNAME} --vault 'Dev'; fi }
op read "op://Dev/${HOSTNAME}/private key?ssh-format=openssh" > "$temp/etc/ssh/ssh_host_ed25519_key"
op read "op://Dev/${HOSTNAME}/public key" > "$temp/etc/ssh/ssh_host_ed25519_key.pub"

# Set the correct permissions so sshd will accept the key
chmod 600 "$temp/etc/ssh/ssh_host_ed25519_key"

# Open secrets file to add new ssh key can
if [[ ! $SECRETS =~ ^[Yy]$ ]]; then
  echo "Skipping secrets"
else
  nix-shell -p ssh-to-age --run ssh-to-age < "${temp}/etc/ssh/ssh_host_ed25519_key.pub" \
    | sed "s/^/- \\&$HOSTNAME /" \
    | copy
  echo "SSH public key copied to clipboard. Press any key to open secrets file and paste it into the secrets.yaml file."
  read -n 1 -s -r -p "Press any key to continue"
  "$EDITOR" ./.sops.yaml
  sops updatekeys ./secrets/secrets.yaml
fi


# Install NixOS to the host system with our secrets
cmd=(
  nix run github:nix-community/nixos-anywhere --
  --extra-files "$temp"
  --flake ".#$HOSTNAME"
  "${GENHARD[@]}"
  --target-host "${TARGET[@]}"
)

printf '%q ' "${cmd[@]}"
echo
"${cmd[@]}"

