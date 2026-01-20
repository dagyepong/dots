
#!/bin/sh

[ "$(basename "$PWD")" = "zish" ] && ZISHDIR="$PWD" || mustbedir
if [ "$EUID" -eq 0 ]; then
  read -p "Warning: changes made as root user only affect the root user. Continue? (y/n)" ROOTCONFIRM
  [ "$ROOTCONFIRM" = "n" ] && exit
fi

[ -f /bin/zsh ] || exit 1
[ -f "$HOME/.zshrc" ] && mv "$HOME/.zshrc" "$HOME/zshrc.old" && echo "~/.zshrc moved to ~/zshrc.old"

echo 'export ZDOTDIR=$HOME/.config/zsh' | doas tee -a /etc/zsh/zshenv
mkdir -p "$HOME/.config/zsh/"
cp "$ZISHDIR/zshrc" "$HOME/.config/zsh/.zshrc"

[ -d /usr/share/zsh/plugins/ ] || doas mkdir -p /usr/share/zsh/plugins/
cd /usr/share/zsh/plugins/

doas git clone https://github.com/zsh-users/zsh-syntax-highlighting.git
doas git clone https://github.com/zsh-users/zsh-autosuggestions.git
doas git clone https://github.com/zsh-users/zsh-history-substring-search.git
doas git clone https://github.com/zsh-users/zsh-completions.git
cd -

echo "Done!"
