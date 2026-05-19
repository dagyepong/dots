#!/usr/bin/env bash

CONFIG_DIR="$1"

if [ -z "$CONFIG_DIR" ]; then
    echo "Usage: $0 <config_dir>" >&2
    exit 1
fi

apply_gtk3_colors() {
    local config_dir="$1"

    local gtk3_dir="$config_dir/gtk-3.0"
    local hype_colors="$gtk3_dir/hype-colors.css"
    local gtk_css="$gtk3_dir/gtk.css"

    if [ ! -f "$hype_colors" ]; then
        echo "Error: hype-colors.css not found at $hype_colors" >&2
        echo "Run matugen first to generate theme files" >&2
        exit 1
    fi

    if [ -L "$gtk_css" ]; then
        rm "$gtk_css"
    elif [ -f "$gtk_css" ]; then
        mv "$gtk_css" "$gtk_css.backup.$(date +%s)"
        echo "Backed up existing gtk.css"
    fi

    ln -s "hype-colors.css" "$gtk_css"
    echo "Created symlink: $gtk_css -> hype-colors.css"
}

apply_gtk4_colors() {
    local config_dir="$1"

    local gtk4_dir="$config_dir/gtk-4.0"
    local hype_colors="$gtk4_dir/hype-colors.css"
    local gtk_css="$gtk4_dir/gtk.css"
    local gtk4_import="@import url(\"hype-colors.css\");"

    if [ ! -f "$hype_colors" ]; then
        echo "Error: GTK4 hype-colors.css not found at $hype_colors" >&2
        echo "Run matugen first to generate theme files" >&2
        exit 1
    fi

    if [ -f "$gtk_css" ] && grep -q '^@import url.*hype-colors\.css.*);$' "$gtk_css"; then
        echo "GTK4 import already exists"
        return
    fi

    if [ -f "$gtk_css" ] && [ -s "$gtk_css" ]; then
        sed -i "1i\\$gtk4_import" "$gtk_css"
    else
        echo "$gtk4_import" >"$gtk_css"
    fi
    echo "Updated GTK4 CSS import"
}

mkdir -p "$CONFIG_DIR/gtk-3.0" "$CONFIG_DIR/gtk-4.0"

apply_gtk3_colors "$CONFIG_DIR"
apply_gtk4_colors "$CONFIG_DIR"

echo "GTK colors applied successfully"
