bw-new-item() {
  if [[ "${1}" == "-h" || "${1}" == "--help" ]]; then
    echo "Usage: bw-new-item <item-name> <item-username>"
    echo ""
    echo "Creates a new Bitwarden item with the specified name."
    echo "Generates a random password automatically."
    return 0
  fi
  
  if [[ -z "${1}" ]]; then
    echo "Error: item name and username is required"
    echo "Use 'bw-new-item --help' for usage information"
    return 1
  fi
  
  export BW_SESSION=$(bw unlock --raw)
  local item_name="${1}"
  local password=$(bw generate -ulns)
  local organizationId="f9bb87fe-6c97-40c5-8f53-d43901f548ce"
  local collectionId="c68c3d1f-dc7c-496a-8e97-bd2bc65a9601"
  local login_template=$(bw get template item.login | jq --arg user "${item_name}" --arg pass "${password}" '.username=$user | .password=$pass | .totp=null')
  bw get template item | jq --arg name "${item_name}" --arg oid "${organizationId}" --arg cid "${collectionId}" --argjson login "${login_template}" '.name=$name | .organizationId=$oid | .collectionIds=[$cid] | .notes=null | .login=$login' | bw encode | bw create item
}
