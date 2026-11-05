# prints the normalised shortcuts defined in niri .kdl files:  awk -f keys.awk -f niri-keys.awk file...
/^[ \t]*[A-Z][A-Za-z0-9_+]*([ \t]+[a-z-]+=[^ \t]+)*[ \t]*\{/ {
    t = $1
    print norm(t)
}
