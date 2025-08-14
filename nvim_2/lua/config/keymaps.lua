-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- remove <cmd>Lazy<CR> init keymap
vim.keymap.del("n", "<leader>l")
require("harpoon").setup() -- then add harpoon
vim.keymap.set("n", "<leader>l", function()
  require("harpoon"):list():select(3)
end)

vim.keymap.set("i", "jk", "<Esc>")
