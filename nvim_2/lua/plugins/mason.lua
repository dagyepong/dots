return {
  "williamboman/mason.nvim",
  enabled = true,
  dependencies = {
    "williamboman/mason-lspconfig.nvim",
    "WhoIsSethDaniel/mason-tool-installer.nvim",
  },
  config = function()
    local mason = require("mason")
    local mason_lspconfig = require("mason-lspconfig")
    local mason_tool_installer = require("mason-tool-installer")

    mason.setup({
      -- and opts here
    })

    mason_lspconfig.setup({
      ensure_installed = {
        "html",
        "cssls",
        "svelte",
        "lua_ls",
        "pyright",
        "bashls",
        "clangd",
        "perlnavigator",
        "dockerls",
        "docker_compose_language_service",
      },
    })

    mason_tool_installer.setup({
      ensure_installed = {
        "prettier",
        "black",
        "eslint_d",
        "ruff",
      },
    })
  end,
}
