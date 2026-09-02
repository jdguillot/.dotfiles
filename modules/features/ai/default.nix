# AI feature namespace: cyberfighter.features.ai.*, one subdirectory per
# agent/runtime. The split that matters: `ollama` serves models, everything
# else consumes them through the one server -- N runtimes means N copies of
# the weights on one GPU.
{
  imports = [
    ./comfyui/default.nix
    ./comfyui/openai-api.nix
    ./comfyui/server.nix
    ./hermes/default.nix
    ./litellm/default.nix
    ./odysseus/default.nix
    ./ollama/default.nix
  ];
}
