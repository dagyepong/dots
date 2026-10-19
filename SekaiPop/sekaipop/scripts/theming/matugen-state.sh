#!/bin/sh

# Helper for ThemeService.qml's "Wallpaper (matugen)" theme: runs matugen on
# a wallpaper and leaves the colours where the shell reads them.
#
#   matugen-state.sh apply <image> [scheme-type] [name]
#   matugen-state.sh check            (prints what it found, for debugging)
#
# It uses its own tiny matugen config (written on every run, next to the
# output), so ONLY matugen-template.json is rendered: your own
# ~/.config/matugen/config.toml (GTK, kitty, ...) is not touched and none of
# its hooks run. The result is
#   ${XDG_CACHE_HOME:-~/.cache}/sekaipop/matugen/colors.json
# which ThemeService.qml watches and re-colours the shell from. With a [name]
# (the lockscreen uses "lock-colors") the file is <name>.json and the config is
# <name>.toml instead, so two runs for two wallpapers never share a file.
#
# matugen's flags differ a little between versions, so `apply` tries the
# command with --quiet first and, if matugen rejects the arguments, again
# without it. Whatever matugen says is passed through on stderr (the shell
# logs it as "[ThemeService] matugen: ...").
#
# Exit codes: 0 done, 2 bad arguments / image missing, 3 matugen ran but
# wrote no usable colors.json, 127 matugen not installed, anything else is
# matugen's own.

mode="$1"
cachedir="${XDG_CACHE_HOME:-$HOME/.cache}/sekaipop/matugen"
here="$(cd "$(dirname "$0")" && pwd)"
out="$cachedir/colors.json"

case "$mode" in
    check)
        if command -v matugen >/dev/null 2>&1; then
            echo "matugen: $(command -v matugen)"
            matugen --version 2>&1 | head -n 1
        else
            echo "matugen: NOT FOUND on PATH ($PATH)"
        fi
        echo "template: $here/matugen-template.json ($([ -f "$here/matugen-template.json" ] && echo ok || echo MISSING))"
        echo "output:   $out ($([ -f "$out" ] && echo exists || echo "not written yet"))"
        ;;
    apply)
        img="$2"
        type="${3:-scheme-tonal-spot}"
        name="${4:-colors}"
        out="$cachedir/$name.json"
        [ -f "$img" ] || { echo "matugen-state: no such image: $img" >&2; exit 2; }
        command -v matugen >/dev/null 2>&1 || { echo "matugen-state: matugen is not installed (not on the shell's PATH)" >&2; exit 127; }
        mkdir -p "$cachedir" || exit 1
        cfg="$cachedir/config.toml"
        [ "$name" = "colors" ] || cfg="$cachedir/$name.toml"
        # matugen renders into a NEW file next to the real one, and the real one is only
        # replaced (mv, atomic) once the new one is complete. It used to delete colors.json
        # first, so a shell killed or reloaded in the middle of a run left no colours at all,
        # and the next start fell back to the default theme (and painted the terminal and
        # prompt with it).
        new="$out.new"
        printf "[config]\n\n[templates.sekaipop]\ninput_path = '%s'\noutput_path = '%s'\n" \
            "$here/matugen-template.json" "$new" > "$cfg" || exit 1

        rm -f "$new"
        # matugen 4.x asks you to pick a source colour from a prompt when the
        # image has several; the shell has no terminal, so that prompt fails
        # ("IO error: not a terminal"). --source-color-index 0 picks the most
        # dominant colour without asking. Older matugen doesn't know that flag
        # (or --quiet), so if the first run fails the flags are dropped one
        # group at a time.
        matugen image "$img" --config "$cfg" --mode dark --type "$type" --source-color-index 0 --quiet
        rc=$?
        if [ "$rc" -ne 0 ] && [ ! -s "$new" ]; then
            echo "matugen-state: run failed (exit $rc), retrying without --quiet" >&2
            matugen image "$img" --config "$cfg" --mode dark --type "$type" --source-color-index 0
            rc=$?
        fi
        if [ "$rc" -ne 0 ] && [ ! -s "$new" ]; then
            echo "matugen-state: run failed (exit $rc), retrying without --source-color-index (older matugen)" >&2
            matugen image "$img" --config "$cfg" --mode dark --type "$type"
            rc=$?
        fi
        [ "$rc" -eq 0 ] || exit "$rc"

        if [ ! -s "$new" ] || ! grep -q '"dark"' "$new"; then
            echo "matugen-state: matugen exited fine but $new is missing or empty (template not rendered?)" >&2
            rm -f "$new"
            exit 3
        fi
        mv -f "$new" "$out" || exit 1
        ;;
    *)
        echo "usage: $0 apply <image> [scheme-type] | check" >&2
        exit 2
        ;;
esac
