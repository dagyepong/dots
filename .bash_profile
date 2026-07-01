# /home/nana/.bash_profile

# Only launch Mango if we are on TTY1 and no X session is running
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    dbus-run-session niri --session
fi

# Source .bashrc for all other shells
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi
