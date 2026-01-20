# Starting DOOM EMACS daemon

# Check if Emacs daemon is running
if pgrep -f "emacs --daemon" > /dev/null; then
    export EMACS_DAEMON_EXECUTED=0
else
    export EMACS_DAEMON_EXECUTED=1
fi

# Check if the environment variable is set
if [[ $EMACS_DAEMON_EXECUTED -eq 1 ]]; then
    # Execute the command
    emacs --daemon > /dev/null 2>&1

    # Set the environment variable
    export EMACS_DAEMON_EXECUTED=0
fi
