```bash

cargo install --git https://github.com/hase9awa/termtypist --locked
```

```bash

export PATH="$HOME/.cargo/bin:$PATH"

source ~/.bashrc  # Or source ~/.zshrc if using zsh

which termtypist
```

```bash
termtypist
termtypist --time 30
termtypist --words 50 --dictionary english
termtypist quote --length medium
termtypist custom text.txt
cat text.txt | termtypist custom
termtypist stats
termtypist replay last
termtypist theme list
termtypist theme set catppuccin
termtypist config export > config.toml
termtypist config import config.toml
```