return {
  "saghen/blink.cmp",
  opts = {
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
      providers = {
        snippets = {
          opts = {
            search_paths = {
              vim.fn.stdpath("config") .. "/snippets",
              vim.fn.getcwd() .. "/.vscode",
            },
            friendly_snippets = true,
            extended_filetypes = {},
          },
        },
      },
    },
  },
}
