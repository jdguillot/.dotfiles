#!/usr/bin/env bash

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Provision a NixOS host using nixos-anywhere with 1Password-managed SSH keys.

Options:
  -n, --hostname NAME        Hostname for the NixOS configuration
  -t, --target TARGET        Target as user@host followed by any additional SSH
                             options (-p PORT, -i KEY, -J JUMP, -l USER,
                             -o Key=Value). Consumes args until the next script
                             flag is encountered.
  -c, --hardware-config      Generate hardware-configuration.nix
      --no-hardware-config   Skip generating hardware-configuration.nix
  -s, --secrets              Add this host to the secrets/sops config
      --no-secrets           Skip secrets setup
  -S, --ssh-host             Add this host to home/modules/features/ssh/ssh-hosts.yaml
                             and to one or more home-manager users' ssh.hosts list
      --no-ssh-host          Skip ssh-hosts.yaml integration
  -u, --user USER            Home-manager user to add the new host to (repeatable;
                             implies --ssh-host)
  -h, --help                 Show this help message and exit

If options are not provided, the script will prompt interactively.
EOF
}

# Insert a host alias into the ssh.hosts list of a home-manager user's home.nix
add_ssh_host_to_home() {
  local user="$1"
  local host="$2"
  local file="./home/${user}/home.nix"

  if [[ ! -f "$file" ]]; then
    echo "Skipping ${user}: ${file} does not exist" >&2
    return 1
  fi

  if grep -q "^[[:space:]]*\"${host}\"[[:space:]]*$" "$file"; then
    echo "Skipping ${user}: ${host} already present in ${file}"
    return 0
  fi

  awk -v host="$host" '
    !added && /^[[:space:]]*ssh = \{/ { in_ssh = 1 }
    in_ssh && !added && /^[[:space:]]*hosts = \[/ { in_block = 1 }
    in_block && !added && /^[[:space:]]*\]/ {
      if (item_indent == "") {
        match($0, /^[[:space:]]*/)
        item_indent = substr($0, 1, RLENGTH) "  "
      }
      print item_indent "\"" host "\""
      added = 1
      in_block = 0
      in_ssh = 0
    }
    in_block && item_indent == "" && /"/ {
      match($0, /^[[:space:]]*/)
      item_indent = substr($0, 1, RLENGTH)
    }
    { print }
    END { if (!added) exit 1 }
  ' "$file" > "$file.tmp"

  if [[ $? -ne 0 ]]; then
    rm -f "$file.tmp"
    echo "Failed to locate ssh.hosts list in ${file}. Add ${host} manually." >&2
    return 1
  fi

  mv "$file.tmp" "$file"
  echo "Added ${host} to ${file}"
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
SSHHOST=""
HOMEUSERS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--hostname)
      HOSTNAME="$2"
      shift 2
      ;;
    -t|--target)
      shift
      while [[ $# -gt 0 ]]; do
        case "$1" in
          -n|--hostname|-c|--hardware-config|--no-hardware-config|\
          -s|--secrets|--no-secrets|-S|--ssh-host|--no-ssh-host|\
          -u|--user|-h|--help)
            break ;;
          *) TARGET+=("$1"); shift ;;
        esac
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
    -S|--ssh-host)
      SSHHOST="y"
      shift
      ;;
    --no-ssh-host)
      SSHHOST="N"
      shift
      ;;
    -u|--user)
      HOMEUSERS+=("$2")
      SSHHOST="${SSHHOST:-y}"
      shift 2
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
[[ -z "$HOSTNAME" ]] && read -e -r -p "What is the hostname: " HOSTNAME
[[ ${#TARGET[@]} -eq 0 ]] && read -e -r -p "What is the target? user@host [additional_ssh_options]: " -a TARGET
[[ -z "$HARDCONFIG" ]] && read -e -r -p "Do you want to create a hardware-configuration.nix? [Y/n]: " HARDCONFIG
[[ -z "$SECRETS" ]] && read -e -r -p "Should this host be able to access secrets? [y/N]: " SECRETS
[[ -z "$SSHHOST" ]] && read -e -r -p "Add this host to the home-manager ssh-hosts file? [y/N]: " SSHHOST

# If ssh-host integration is enabled but no users were specified, prompt for them
if [[ $SSHHOST =~ ^[Yy]$ && ${#HOMEUSERS[@]} -eq 0 ]]; then
  AVAILABLE_USERS=()
  for d in ./home/*/; do
    name=$(basename "$d")
    [[ "$name" == "modules" ]] && continue
    [[ -f "${d}home.nix" ]] && AVAILABLE_USERS+=("$name")
  done
  echo "Available home-manager users: ${AVAILABLE_USERS[*]}"
  read -e -r -p "Which user(s) to add this host to? (space/comma separated): " HOMEUSERS_RAW
  IFS=', ' read -r -a HOMEUSERS <<< "$HOMEUSERS_RAW"
fi

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
op item get $HOSTNAME --vault='Dev' || { read -e -r -p "Do you want to create a key for ${HOSTNAME}? [y/N]: " CREATE_KEY; if [[ $CREATE_KEY =~ ^[Yy]$ ]]; then op item create --category ssh-key --title=${HOSTNAME} --vault 'Dev'; fi }
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
  sops updatekeys ./secrets/secrets.yaml ./secrets/secrets_common.yaml
fi

# Add to home-manager ssh-hosts.yaml and selected users' home.nix files
if [[ $SSHHOST =~ ^[Yy]$ ]]; then
  SSH_USER="${TARGET[0]%%@*}"
  SSH_HOST="${TARGET[0]##*@}"

  SSH_CONFIG="  HostName ${SSH_HOST}
  User ${SSH_USER}"

  i=1
  while [[ $i -lt ${#TARGET[@]} ]]; do
    case "${TARGET[$i]}" in
      -p) ((i++)); SSH_CONFIG+="
  Port ${TARGET[$i]}" ;;
      -i) ((i++)); SSH_CONFIG+="
  IdentityFile ${TARGET[$i]}" ;;
      -J) ((i++)); SSH_CONFIG+="
  ProxyJump ${TARGET[$i]}" ;;
      -l) ((i++)); SSH_CONFIG+="
  User ${TARGET[$i]}" ;;
      -o) ((i++))
          key="${TARGET[$i]%%=*}"
          val="${TARGET[$i]#*=}"
          SSH_CONFIG+="
  ${key} ${val}" ;;
    esac
    ((i++))
  done

  SSH_ENTRY="${HOSTNAME}: |
${SSH_CONFIG}"

  echo "$SSH_ENTRY" | copy

  echo "New ssh-hosts.yaml entry (copied to clipboard):"
  echo
  echo "$SSH_ENTRY"
  echo
  read -n 1 -s -r -p "Press any key to open ssh-hosts.yaml and paste it in"
  echo
  sops ./home/modules/features/ssh/ssh-hosts.yaml

  for user in "${HOMEUSERS[@]}"; do
    [[ -z "$user" ]] && continue
    add_ssh_host_to_home "$user" "$HOSTNAME"
  done
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

