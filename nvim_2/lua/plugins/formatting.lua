return {
  "stevearc/conform.nvim",
  enabled = true,
  opts = {
    formatters_by_ft = {
      python = { "ruff" },
      javascript = { "prettier" },
      typescript = { "prettier" },
      svelte = { "prettier" },
      html = { "prettier" },
      css = { "prettier" },
      json = { "prettier" },
      yaml = { "prettier" },
      markdown = { "prettier" },
    },
  },
}
