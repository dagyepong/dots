return {
  "rest-nvim/rest.nvim",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      table.insert(opts.ensure_installed, "http")
    end,

    vim.keymap.set("n", "<leader>Rr", ":Rest run<CR>", { silent = true, desc = "Run the current command" })

  }
}
