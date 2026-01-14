# Neovim

A modern, feature-rich Neovim configuration focused on performance, aesthetics, and developer productivity.

![dashboard](https://github.com/user-attachments/assets/1a8fe839-d31b-4478-bb60-9793903254ca)


## Features

- 🚀 Based on [LazyVim](https://github.com/LazyVim/LazyVim) for solid plugin management and defaults
- 🧠 AI-assisted coding with [Avante](https://github.com/yetone/avante.nvim) and GitHub Copilot
- ⚡ Fast completion with [Blink.cmp](https://github.com/saghen/blink.cmp)
- 🔍 Intelligent symbol usage tracking
- 🎨 Beautiful aesthetics with Catppuccin and TokyoNight themes
- 📊 Enhanced diagnostics with inline displays
- 📝 Robust LSP configuration
- 🔧 Optimized for performance
- 📋 Task management with Overseer.nvim
- 🧪 Testing environment with Neotest

## Requirements

- Neovim >= 0.11.0
- A working [Rust environment](https://www.rust-lang.org/tools/install) (for building Blink.cmp)
- Git
- A [Nerd Font](https://www.nerdfonts.com/) for icons
- (Optional) [Lazygit](https://github.com/jesseduffield/lazygit) for git integration
- (Optional) [Ripgrep](https://github.com/BurntSushi/ripgrep) for better search

## Installation

```bash
# Back up existing Neovim configuration if needed
mv ~/.config/nvim ~/.config/nvim.backup

# Clone the repository
git clone https://github.com/abzcoding/nv.git ~/.config/nvim

# Start Neovim (plugins will be automatically installed)
nvim
```

> [!IMPORTANT]
> For building blink.cmp you need a working rust environment


> [!NOTE]
> for avante RAG service you need docker and some ollama models, currently it is only enabled for me
> also you need an API key for tavily web integration, check avante.lua file for more information

## Plugin Highlights

- **Avante.nvim**: AI-powered code assistance
- **Blink.cmp**: Fast completion engine
- **Symbol-usage**: Display references, definitions and implementations of document symbol
- **Markview**: Enhanced markdown viewing
- **Neotest**: Framework for running tests
- **Grapple**: Quick file navigation and bookmarking
- **Overseer.nvim**: A task runner and job management plugin for Neovim
- **Tiny-inline-diagnostic**: Improved diagnostics display
- **Bufferline.nvim**: A snazzy bufferline for Neovim
- **Lualine.nvim**: A blazing fast statusline
- **Vim-tpipeline**: Embed your vim statusline in tmux


## Customization

Most configuration can be modified by editing the Lua files in the `~/.config/nvim/lua` directory:

- `config/options.lua` - General Neovim options
- `config/keymaps.lua` - Key mappings
- `config/autocmds.lua` - Autocommands
- `config/utils.lua` - utility functions
- `plugins/*.lua` - Plugin-specific configurations

## Preview

![avante neovim](https://github.com/user-attachments/assets/f1f93baa-892f-48dd-810d-460a205231f8)

![neotest and overseer](https://github.com/user-attachments/assets/0ecde105-2744-4705-800a-35345db47fc9)


## Credits

This configuration is built upon:

- [LazyVim](https://github.com/LazyVim/LazyVim)
- And many other exceptional Neovim plugins
