# Discover the models available on the Ollama server and write them into a
# secondary opencode config, pointed at by $OPENCODE_CONFIG.
#
# opencode (1.18.x) has no model auto-discovery for openai-compatible
# providers, so the models map has to be materialised ahead of time. The
# provider block itself is read back out of the home-manager-generated
# opencode.json, which stays the single source of truth for the baseURL.

config="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/opencode.json"
out="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/ollama.json"
# shellcheck disable=SC2016 # $schema is a literal JSON key, not a variable
stub='{"$schema":"https://opencode.ai/config.json"}'

# Never leave $OPENCODE_CONFIG dangling; opencode reads it unconditionally.
[ -f "$out" ] || echo "$stub" >"$out"

provider=$(jq -c '.provider.ollama // empty' "$config" 2>/dev/null || true)
if [ -z "$provider" ]; then
  echo "opencode: no 'ollama' provider in $config, nothing to sync" >&2
  exit 0
fi

# baseURL is the OpenAI-compatible endpoint; the tag/show APIs are native.
api=$(printf '%s' "$provider" | jq -r '.options.baseURL // empty')
# Resolve opencode-style {file:...}; an unresolved {env:...} means this host
# has no URL configured (private URLs come from sops, see remoteProvider).
case "$api" in
  "{file:"*)
    f=${api#"{file:"}
    api=$(cat "${f%\}}" 2>/dev/null || true)
    ;;
  "{env:"*) api="" ;;
esac
api=$(printf '%s' "$api" | sed 's:/v1/*$::')
if [ -z "$api" ]; then
  echo "opencode: provider.ollama.options.baseURL is unset" >&2
  exit 0
fi

if ! tags=$(curl -fsS --max-time "$TIMEOUT" "$api/api/tags" 2>/dev/null); then
  echo "opencode: $api unreachable, keeping $out as-is" >&2
  exit 0
fi

models='{}'
while read -r model; do
  [ -n "$model" ] || continue
  show=$(curl -fsS --max-time "$TIMEOUT" "$api/api/show" \
    -d "$(jq -nc --arg m "$model" '{model: $m}')" 2>/dev/null) || show='{}'

  models=$(printf '%s' "$show" | jq \
    --argjson acc "$models" \
    --argjson cap "$SERVER_CONTEXT" \
    --arg id "$model" \
    '
    # model_info holds the *architectural* maximum (262144 for Qwen3.x); the
    # server actually loads every model with its fixed OLLAMA_CONTEXT_LENGTH
    # window, mirrored here as $cap. Advertising the bigger number means
    # opencode never auto-compacts and requests die at the real window.
    ([(.model_info // {}) | to_entries[]
      | select(.key | endswith(".context_length")) | .value] | first) as $meta
    | ([$meta // 8192, $cap] | min) as $ctx
    | (.capabilities // []) as $caps
    # Embedding-only models would just be noise in the model picker.
    | if ($caps | index("completion")) == null then $acc else
      $acc + { ($id): {
        id: $id,
        name: $id,
        tool_call: ($caps | index("tools") != null),
        reasoning: ($caps | index("thinking") != null),
        attachment: ($caps | index("vision") != null),
        cost: { input: 0, output: 0 },
        # opencode sends limit.output as max_tokens. Reasoning models spend
        # their thinking budget inside it -- at 8192 a qwen3.x deep-analysis
        # turn gets cut off mid-think, and opencode treats the truncated
        # reply as the answer and silently stops.
        limit: { context: $ctx, output: 32768 },
      } } end
    ')
done <<<"$(printf '%s' "$tags" | jq -r '.models[]?.model')"

count=$(printf '%s' "$models" | jq 'length')
if [ "$count" -eq 0 ]; then
  echo "opencode: $api reported no models, keeping $out as-is" >&2
  exit 0
fi

tmp=$(mktemp)
jq -n --argjson provider "$provider" --argjson models "$models" \
  '{ "$schema": "https://opencode.ai/config.json",
     provider: { ollama: ($provider + { models: $models }) } }' >"$tmp"
mv "$tmp" "$out"
echo "opencode: synced $count Ollama model(s) from $api into $out" >&2
