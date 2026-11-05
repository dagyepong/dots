# prints the normalised shortcuts found in the bind(...) / hl.bind(...) lines of a Hyprland Lua file
#   awk -f keys.awk -f lua-keys.awk file...
function keysIn(line,    s, pre, name, v) {
    while (match(line, /"[^"]*"/)) {
        s = substr(line, RSTART + 1, RLENGTH - 2)
        pre = substr(line, 1, RSTART - 1)
        line = substr(line, RSTART + RLENGTH)
        if (s !~ /^[A-Za-z0-9_ +]+$/) continue
        if (match(pre, /[A-Za-z_][A-Za-z0-9_]*[ \t]*\.\.[ \t]*$/)) {
            name = substr(pre, RSTART, RLENGTH)
            sub(/[ \t]*\.\.[ \t]*$/, "", name)
            v = (name in mods) ? mods[name] : "SUPER"
            s = v s
        }
        print norm(s)
        return
    }
}
/^[ \t]*local[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*=[ \t]*"[A-Za-z]+"[ \t]*$/ {
    n = $2
    v = $0
    sub(/^[^"]*"/, "", v); sub(/".*$/, "", v)
    mods[n] = v
}
/bind[ \t]*\(/ { keysIn($0) }
