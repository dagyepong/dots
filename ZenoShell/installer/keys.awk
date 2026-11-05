# Helpers to compare shortcuts written in different ways (Mod+Alt+T, "SUPER + ALT + T"...)

function sortjoin(a, n,    i, j, t, out) {
    for (i = 1; i <= n; i++)
        for (j = i + 1; j <= n; j++)
            if (a[j] < a[i]) { t = a[i]; a[i] = a[j]; a[j] = t }
    out = a[1]
    for (i = 2; i <= n; i++) out = out "+" a[i]
    return out
}

# one key, any compositor -> "alt+super+t"
function norm(k,    n, a, i) {
    k = tolower(k)
    gsub(/[ \t]/, "", k)
    n = split(k, a, "+")
    for (i = 1; i <= n; i++) {
        if (a[i] == "mod" || a[i] == "win" || a[i] == "super" || a[i] == "meta" || a[i] == "mainmod") a[i] = "super"
        else if (a[i] == "control") a[i] = "ctrl"
    }
    return sortjoin(a, n)
}
