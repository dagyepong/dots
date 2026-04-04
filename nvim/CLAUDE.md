# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

This is a Neovim configuration built on top of LazyVim, using the Lazy.nvim plugin manager. The configuration follows LazyVim's structured approach:

- `init.lua`: Bootstrap entry point that loads the lazy configuration
- `lua/config/`: Core configuration files (lazy setup, options, keymaps, autocmds)  
- `lua/plugins/`: Plugin specifications and customizations
- `lazyvim.json`: LazyVim extras configuration (currently includes clangd and cmake support)

### Key Configuration Files

- `lua/config/lazy.lua`: Main Lazy.nvim setup with LazyVim base and language extras (Go, Java, TypeScript, Python, etc.)
- `lua/config/keymaps.lua`: Custom keymaps including tmux navigation overrides
- `lua/config/options.lua`: Neovim options (swapfiles disabled)
- `lua/plugins/dev.lua`: Development plugins (local plugin development setup)

### Development Plugin Structure

The config includes a development setup for local plugins in `lua/plugins/dev.lua`:
- Active development plugins are loaded from local directories
- Disabled plugins are kept in the config but with `enabled = false`
- Uses `dev = true` and `dir` properties to point to local plugin directories

## Common Commands

### Code Formatting
```bash
# Format Lua files using stylua (configured in stylua.toml)
stylua lua/
```

### Plugin Management
```bash
# Inside Neovim - update plugins
:Lazy update

# Check plugin status
:Lazy

# Clean unused plugins
:Lazy clean
```

### External Dependencies
The configuration requires these external tools:
- [colorscripts](https://github.com/charitarthchugh/shell-color-scripts)
- [hub](https://hub.github.com/)

## File Patterns

- Plugin files: `lua/plugins/*.lua` - Each file should return a table of plugin specifications
- Config files: `lua/config/*.lua` - Configuration modules loaded by LazyVim
- LazyVim extras: Configured in `lazyvim.json` and imported in `lua/config/lazy.lua`

## Custom Keymaps

Notable custom keybindings:
- `jk` in insert mode → Escape
- `K`/`J` → Move 5 lines up/down (original K/J mapped to `<leader>k`/`<leader>j`)
- `<C-hjkl>` → Tmux navigation (overrides LazyVim defaults)
- `gh` → LSP hover
- `:CopyPath` → Copy current file's full path to clipboard