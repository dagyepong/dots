return {
  'stevearc/oil.nvim',
  dependencies = { "nvim-tree/nvim-web-devicons" },   -- use if prefer nvim-web-devicons
  config = function()
    require("oil").setup({
      keymaps = {
        ["L"] = "actions.select",
        ["H"] = "actions.parent",
      },
      view_options = {
        show_hidden = false,
        is_hidden_file = function(name, bufnr)
          local hidden_files = { "env", "__pycache__", ".DS_STORE" }

          for _, value in ipairs(hidden_files) do
            if vim.startswith(name, value) then
              return true
            end
          end
          return false
        end
      },

    })

    local keymap = vim.keymap
    keymap.set('n', '<leader>e', function() require('oil').open_float() end, { desc = 'Open oil in float' })
  end
}
