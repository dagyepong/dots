return {
  'nvim-telescope/telescope.nvim',
  opts = {
    pickers = {
      find_files = {
        hidden = true,
        find_command = {
          "rg",
          "--files",
          "--hidden",
          "--no-ignore",        -- Do not respect ignore files (e.g., .gitignore)
          "--no-ignore-parent", -- Do not respect ignore files in parent directories
          "--follow",           -- Follow symbolic links
          "--glob=!**/.git/*",
          "--glob=!**/.idea/*",
          "--glob=!**/.vscode/*",
          "--glob=!**/build/*",
          "--glob=!**/dist/*",
          "--glob=!**/yarn.lock",
          "--glob=!**/package-lock.json",
          "--glob=!**/venv*/*",
          "--glob=!**/env*/*",
          "--glob=!**/.DS_Store",
          "--glob=!**/__pycache__",
        }
      },
    },
  },
  -- keys = {
  --   { "<leader><space>", "<cmd>Telescope find_files hidden=true,no_ignore=true<CR>", desc = "find files" },
  -- },
}
