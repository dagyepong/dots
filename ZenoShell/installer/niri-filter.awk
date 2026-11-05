# copies a niri shortcuts file, commenting the shortcuts the user already has
#   awk -v logf=FILE -f keys.awk -f niri-filter.awk userkeys src > dst
NR == FNR { u[$0] = 1; next }
{
    if ($0 ~ /^[ \t]*[A-Z][A-Za-z0-9_+]*([ \t]+[a-z-]+=[^ \t]+)*[ \t]*\{/) {
        k = norm($1)
        if (k in u) {
            line = $0
            sub(/^[ \t]+/, "", line)
            print "    // skipped, already in your config: " line
            print $1 >> logf
            next
        }
    }
    print
}
