# keeps the shell shortcuts (the bind lines that call qs(...)) of quickshell-binds.lua,
# drops the others (apps, windows, workspaces) and comments the ones the user already has
#   awk -v logf=FILE -f keys.awk -f lua-filter.awk userkeys src > dst
function keyOf(line,    s, pre, name, v) {
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
        return s
    }
    return ""
}
NR == FNR { u[$0] = 1; next }
/^[ \t]*local[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*=[ \t]*"[A-Za-z]+"[ \t]*$/ {
    n = $2
    v = $0
    sub(/^[^"]*"/, "", v); sub(/".*$/, "", v)
    mods[n] = v
}
/^[ \t]*bind[ \t]*\(/ {
    if ($0 !~ /qs[ \t]*\(/) next            # not a shell shortcut: not installed in light mode
    raw = keyOf($0)
    if (raw != "" && (norm(raw) in u)) {
        line = $0
        sub(/^[ \t]+/, "", line)
        print "    -- skipped, already in your config: " line
        print raw >> logf
        next
    }
}
{ print }
