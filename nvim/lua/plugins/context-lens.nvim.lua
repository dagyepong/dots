return {
  {
    dir = "~/.config/nvim/dev/context-lens.nvim",
    name = "context-lens.nvim",
    lazy = false,
    opts = {
      icon = "󱞣 ",
    },
    config = function(_, opts)
      vim.api.nvim_create_user_command("FocusContext", function()
        local line = vim.api.nvim_win_get_cursor(0)[1]
        local file = vim.fn.expand("%:t")
        vim.notify(opts.icon .. " Active Context: " .. file .. " (Line " .. line .. ")")
      end, {
        desc = "Notify current file and cursor line",
      })
    end,
  },
}
