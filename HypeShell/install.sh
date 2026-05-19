#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
DEFAULT_REPO_URL="https://github.com/acarlton5/HypeShell.git"
INSTALLER_BUILD_ID="hype-shade-update-v1"

YES=1
PURGE_USER_DATA=0
SKIP_INSTALL=0
SKIP_PACKAGE_REMOVAL=0
REMOVE_HYPE_PACKAGES=0
UPDATE_EXISTING=0
INSTALL_GREETER=1
INSTALL_HYPRLAND_SESSION=1
INSTALL_METHOD="source"
CLEAN_DISPLAY_MANAGER=1
ALLOW_UPSTREAM_PACKAGES=0
REBOOT_IF_NEEDED=0
AUTO_REBOOT_IF_NEEDED=0
NEEDS_REBOOT=0
REPO_URL="$DEFAULT_REPO_URL"
BRANCH="main"
PREFIX="/usr/local"
SOURCE_DIR=""
BACKUP_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/Hype/install-backups"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"
WORK_DIR="${TMPDIR:-/tmp}/hypeshell-install-$TIMESTAMP"
FINGERPRINT_PATH="$PREFIX/share/hypeshell/install-fingerprint"

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [options]

Install the Hyprland-only HypeShell system from source.
Run with no flags for a clean install. Use --update to repair/update an existing install.

Options:
  --update              Repair/update an existing HypeShell install and remove legacy upstream packages.
  --dry-run             Print what would happen without making changes.
  --yes                 Compatibility no-op; installs run by default.
  --purge-user-data     Delete old user config/state/cache instead of backing it up.
  --skip-install        Only clean or repair system/session artifacts.
  --skip-package-removal
                        Do not ask the distro package manager to remove old packages.
  --remove-upstream-packages
                        Remove installed legacy upstream shell packages too.
  --install-method MODE Install method for the replacement system:
                        source   build/install this HypeShell repo from source (default).
                        Package installs are intentionally disabled.
  --allow-upstream-packages
                        Compatibility no-op; upstream package installs remain disabled.
  --skip-greeter        Do not install/configure greetd and the HypeShell greeter.
  --install-greeter     Compatibility no-op; greeter install is enabled by default.
                        This replaces SDDM/GDM/LightDM with greetd.
  --skip-hyprland-session
                        Do not install the HypeShell-owned Hyprland session files.
                        This is only for recovery/debugging; HypeShell targets Hyprland.
  --clean               Remove old upstream packages and remove the sddm package
                        after greeter setup succeeds.
  --reboot-if-needed    Prompt to reboot at the end if the install changed boot/login
                        components or the system reports that a reboot is required.
  --auto-reboot-if-needed
                        Reboot automatically at the end when a reboot is required.
  --repo URL            HypeShell git repository to install from.
                        Default: $DEFAULT_REPO_URL
  --branch NAME         Branch to clone when --source is not used. Default: main.
  --source DIR          Install from an existing local Hype checkout.
  --prefix DIR          Install prefix. Default: /usr/local.
  -h, --help            Show this help.

Examples:
  $SCRIPT_NAME
  $SCRIPT_NAME --update
  $SCRIPT_NAME --source ~/src/HypeShell
  $SCRIPT_NAME --update --purge-user-data --skip-install
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --update)
            UPDATE_EXISTING=1
            REMOVE_HYPE_PACKAGES=1
            CLEAN_DISPLAY_MANAGER=1
            ;;
        --dry-run)
            YES=0
            ;;
        --yes)
            YES=1
            ;;
        --purge-user-data)
            PURGE_USER_DATA=1
            ;;
        --skip-install)
            SKIP_INSTALL=1
            ;;
        --skip-package-removal)
            SKIP_PACKAGE_REMOVAL=1
            ;;
        --remove-upstream-packages|--remove-hype-packages)
            REMOVE_HYPE_PACKAGES=1
            ;;
        --install-method)
            INSTALL_METHOD="${2:-}"
            shift
            ;;
        --allow-upstream-packages)
            ALLOW_UPSTREAM_PACKAGES=1
            ;;
        --install-greeter)
            INSTALL_GREETER=1
            ;;
        --skip-greeter)
            INSTALL_GREETER=0
            CLEAN_DISPLAY_MANAGER=0
            ;;
        --skip-hyprland-session)
            INSTALL_HYPRLAND_SESSION=0
            ;;
        --clean)
            CLEAN_DISPLAY_MANAGER=1
            REMOVE_HYPE_PACKAGES=1
            ;;
        --reboot-if-needed)
            REBOOT_IF_NEEDED=1
            ;;
        --auto-reboot-if-needed)
            REBOOT_IF_NEEDED=1
            AUTO_REBOOT_IF_NEEDED=1
            ;;
        --remove-sddm-package)
            CLEAN_DISPLAY_MANAGER=1
            ;;
        --repo)
            REPO_URL="${2:-}"
            shift
            ;;
        --branch)
            BRANCH="${2:-}"
            shift
            ;;
        --source)
            SOURCE_DIR="${2:-}"
            shift
            ;;
        --prefix)
            PREFIX="${2:-}"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

FINGERPRINT_PATH="$PREFIX/share/hypeshell/install-fingerprint"

if [ "$INSTALL_METHOD" != "source" ]; then
    echo "Error: HypeShell installs only from the HypeShell source repo." >&2
    echo "Use the default source install; upstream package installs are disabled." >&2
    exit 2
fi

if [ "$(uname -s)" != "Linux" ]; then
    echo "Error: this installer is intended for Linux." >&2
    exit 1
fi

SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_PATH")" >/dev/null 2>&1 && pwd -P || true)"
if [ -z "$SOURCE_DIR" ] && [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/quickshell/shell.qml" ] && [ -f "$SCRIPT_DIR/core/Makefile" ]; then
    SOURCE_DIR="$SCRIPT_DIR"
fi

if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    echo "Error: run as your normal user. The script will use sudo only where needed." >&2
    exit 1
fi

run() {
    if [ "$YES" -eq 1 ]; then
        "$@"
    else
        printf '[dry-run] '
        printf '%q ' "$@"
        printf '\n'
    fi
}

have() {
    command -v "$1" >/dev/null 2>&1
}

sudo_run() {
    if [ "${HYPESHELL_INSTALL_PRIVESC:-}" = "pkexec" ]; then
        if have pkexec; then
            run pkexec "$@"
            return
        fi
        echo "Error: pkexec is required for HypeShell GUI updater privileged steps." >&2
        exit 1
    fi

    if have sudo; then
        run sudo "$@"
    else
        echo "Error: sudo is required for system install/removal steps." >&2
        exit 1
    fi
}

path_exists() {
    [ -e "$1" ] || [ -L "$1" ]
}

existing_hypeshell_install_detected() {
    have hype && return 0
    path_exists "$PREFIX/bin/hype" && return 0
    path_exists "$PREFIX/share/quickshell/hype" && return 0
    path_exists "$PREFIX/share/quickshell/hype" && return 0
    return 1
}

backup_or_remove() {
    path="$1"
    if ! path_exists "$path"; then
        return 0
    fi

    if [ "$PURGE_USER_DATA" -eq 1 ]; then
        run rm -rf "$path"
        return 0
    fi

    relative="${path#$HOME/}"
    destination="$BACKUP_DIR/$relative"
    run mkdir -p "$(dirname "$destination")"
    run mv "$path" "$destination"
}

remove_if_exists() {
    path="$1"
    if path_exists "$path"; then
        sudo_run rm -rf "$path"
    fi
}

remove_user_file_if_exists() {
    path="$1"
    if path_exists "$path"; then
        run rm -f "$path"
    fi
}

backup_legacy_children() {
    parent="$1"
    [ -d "$parent" ] || return 0

    for child in "$parent"/HYPE* "$parent"/Hype* "$parent"/hype*; do
        [ -e "$child" ] || [ -L "$child" ] || continue
        backup_or_remove "$child"
    done
}

import_legacy_hype_material_data() {
    [ "$PURGE_USER_DATA" -eq 0 ] || return 0

    legacy_config="$HOME/.config/HypeMaterialShell"
    hype_config="$HOME/.config/HypeShell"
    legacy_state="${XDG_STATE_HOME:-$HOME/.local/state}/HypeMaterialShell"
    hype_state="${XDG_STATE_HOME:-$HOME/.local/state}/HypeShell"
    legacy_cache="${XDG_CACHE_HOME:-$HOME/.cache}/HypeMaterialShell"
    hype_cache="${XDG_CACHE_HOME:-$HOME/.cache}/HypeShell"

    for file in settings.json plugin_settings.json clsettings.json; do
        if [ -f "$legacy_config/$file" ] && [ ! -e "$hype_config/$file" ]; then
            run mkdir -p "$hype_config"
            run cp -a "$legacy_config/$file" "$hype_config/$file"
        fi
    done

    for file in session.json appusage.json; do
        if [ -f "$legacy_state/$file" ] && [ ! -e "$hype_state/$file" ]; then
            run mkdir -p "$hype_state"
            run cp -a "$legacy_state/$file" "$hype_state/$file"
        fi
    done

    for file in cache.json launcher_cache.json hype-colors.json; do
        if [ -f "$legacy_cache/$file" ] && [ ! -e "$hype_cache/$file" ]; then
            run mkdir -p "$hype_cache"
            run cp -a "$legacy_cache/$file" "$hype_cache/$file"
        fi
    done

    for kind in plugins themes; do
        src="$legacy_config/$kind"
        dst="$HOME/.config/HypeShell/$kind"
        [ -d "$src" ] || continue
        run mkdir -p "$dst"
        for child in "$src"/*; do
            [ -e "$child" ] || [ -L "$child" ] || continue
            name="$(basename "$child")"
            if [ ! -e "$dst/$name" ] && [ ! -L "$dst/$name" ]; then
                run cp -a "$child" "$dst/$name"
            fi
        done
    done
}

stop_disable_user_units() {
    if ! have systemctl; then
        return 0
    fi

    legacy_units=(
        hypeshell.service
        hype-shell.service
        hype-updater.service
        HYPESHELL.service
        hype.service
    )

    for unit in "${legacy_units[@]}"; do
        run systemctl --user stop "$unit" 2>/dev/null || true
        run systemctl --user disable "$unit" 2>/dev/null || true
    done

    if [ "$UPDATE_EXISTING" -eq 0 ]; then
        run systemctl --user stop hype.service 2>/dev/null || true
        run systemctl --user disable hype.service 2>/dev/null || true
    fi

    run systemctl --user daemon-reload || true
}

kill_legacy_processes() {
    names=(
        hypeshell
        hype-shell
        HYPESHELL
        hypeupdater
        hype-updater
    )

    for name in "${names[@]}"; do
        run pkill -TERM -x "$name" 2>/dev/null || true
    done

    if [ "$UPDATE_EXISTING" -eq 0 ]; then
        run pkill -TERM -x hype 2>/dev/null || true
    fi
    run pkill -TERM -x hype 2>/dev/null || true
    sleep 1
}

remove_legacy_packages() {
    if [ "$SKIP_PACKAGE_REMOVAL" -eq 1 ]; then
        echo "Skipping distro package removal."
        return 0
    fi

    package_candidates=(
        hypeshell
        hype-shell
        hype-shell-git
        hypeupdater
        hype-updater
        hypeshell-git
    )

    if [ "$REMOVE_HYPE_PACKAGES" -eq 1 ]; then
        package_candidates+=(
            hype
            hype-cli
            hype-git
            hype-greeter
            hype-hyprland
            hype-niri
            hype-shell
            hype-shell-git
            hype-shell-hyprland
            hype-shell-niri
            greetd-hype-greeter-git
        )
    fi

    if have pacman; then
        installed=()
        for pkg in "${package_candidates[@]}"; do
            if pacman -Q "$pkg" >/dev/null 2>&1; then
                installed+=("$pkg")
            fi
        done
        if [ "${#installed[@]}" -gt 0 ]; then
            sudo_run pacman -Rns --noconfirm "${installed[@]}"
        fi
    elif have rpm; then
        installed=()
        for pkg in "${package_candidates[@]}"; do
            if rpm -q "$pkg" >/dev/null 2>&1; then
                installed+=("$pkg")
            fi
        done
        if [ "${#installed[@]}" -gt 0 ]; then
            if have dnf; then
                sudo_run dnf remove -y "${installed[@]}"
            elif have zypper; then
                sudo_run zypper --non-interactive remove "${installed[@]}"
            else
                sudo_run rpm -e "${installed[@]}"
            fi
        fi
    elif have dpkg-query; then
        installed=()
        for pkg in "${package_candidates[@]}"; do
            if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
                installed+=("$pkg")
            fi
        done
        if [ "${#installed[@]}" -gt 0 ]; then
            sudo_run apt-get remove -y "${installed[@]}"
        fi
    fi
}

remove_legacy_user_artifacts() {
    backup_or_remove "$HOME/.config/quickshell/hype-shell"
    backup_or_remove "$HOME/.config/quickshell/hypeshell"
    backup_or_remove "$HOME/.config/HYPESHELL"
    backup_or_remove "$HOME/.config/hypeshell"
    backup_or_remove "$HOME/.config/hype-shell"
    backup_or_remove "$HOME/.config/HYPESTORE"
    backup_or_remove "$HOME/.config/HypeStore"
    backup_or_remove "$HOME/.config/hypestore"
    backup_or_remove "$HOME/.config/hype-store"
    backup_or_remove "$HOME/.local/share/HYPESHELL"
    backup_or_remove "$HOME/.local/share/hypeshell"
    backup_or_remove "$HOME/.local/share/hype-shell"
    backup_or_remove "$HOME/.local/share/HYPESTORE"
    backup_or_remove "$HOME/.local/share/HypeStore"
    backup_or_remove "$HOME/.local/share/hypestore"
    backup_or_remove "$HOME/.local/share/hype-store"
    backup_or_remove "$HOME/.local/state/HYPESHELL"
    backup_or_remove "$HOME/.local/state/hypeshell"
    backup_or_remove "$HOME/.local/state/hype-shell"
    backup_or_remove "$HOME/.local/state/HYPESTORE"
    backup_or_remove "$HOME/.local/state/HypeStore"
    backup_or_remove "$HOME/.local/state/hypestore"
    backup_or_remove "$HOME/.local/state/hype-store"
    backup_or_remove "$HOME/.cache/HYPESHELL"
    backup_or_remove "$HOME/.cache/hypeshell"
    backup_or_remove "$HOME/.cache/hype-shell"
    backup_or_remove "$HOME/.cache/HYPESTORE"
    backup_or_remove "$HOME/.cache/HypeStore"
    backup_or_remove "$HOME/.cache/hypestore"
    backup_or_remove "$HOME/.cache/hype-store"

    remove_user_file_if_exists "$HOME/.config/systemd/user/hypeshell.service"
    remove_user_file_if_exists "$HOME/.config/systemd/user/hype-shell.service"
    import_legacy_hype_material_data

    if [ "$UPDATE_EXISTING" -eq 0 ]; then
        remove_user_file_if_exists "$HOME/.config/systemd/user/hype.service"
    fi
    remove_user_file_if_exists "$HOME/.config/systemd/user/hype-updater.service"
    remove_user_file_if_exists "$HOME/.local/bin/hypeshell"
    remove_user_file_if_exists "$HOME/.local/bin/hype-shell"
    remove_user_file_if_exists "$HOME/.local/bin/hypeupdater"
    remove_user_file_if_exists "$HOME/.local/bin/hype-updater"
    remove_user_file_if_exists "$HOME/.local/share/applications/hypeshell.desktop"
    remove_user_file_if_exists "$HOME/.local/share/applications/hype-shell.desktop"
    remove_user_file_if_exists "$HOME/.local/share/applications/hype-updater.desktop"
    remove_user_file_if_exists "$HOME/.local/share/applications/hype-store.desktop"

    backup_legacy_children "$HOME/.config/HypeMaterialShell/plugins"
    backup_legacy_children "$HOME/.config/HypeMaterialShell/themes"
    backup_legacy_children "$HOME/.local/share/HypeMaterialShell/plugins"
    backup_legacy_children "$HOME/.local/share/HypeMaterialShell/themes"
}

remove_legacy_system_artifacts() {
    remove_if_exists /usr/local/bin/hypeshell
    remove_if_exists /usr/local/bin/hype-shell
    remove_if_exists /usr/local/bin/hypeupdater
    remove_if_exists /usr/local/bin/hype-updater
    remove_if_exists /usr/local/bin/hype
    remove_if_exists /usr/local/bin/hype-greeter
    remove_if_exists /usr/bin/hypeshell
    remove_if_exists /usr/bin/hype-shell
    remove_if_exists /usr/bin/hypeupdater
    remove_if_exists /usr/bin/hype-updater
    remove_if_exists /usr/bin/hype
    remove_if_exists /usr/bin/hype-greeter
    remove_if_exists /usr/local/share/quickshell/hype-shell
    remove_if_exists /usr/local/share/quickshell/hypeshell
    remove_if_exists /usr/local/share/quickshell/hype
    remove_if_exists /usr/local/share/hype-shell
    remove_if_exists /usr/local/share/hypeshell
    remove_if_exists /usr/local/share/hype-store
    remove_if_exists /usr/share/quickshell/hype-shell
    remove_if_exists /usr/share/quickshell/hypeshell
    remove_if_exists /usr/share/quickshell/hype
    remove_if_exists /usr/share/hype-shell
    remove_if_exists /usr/share/hypeshell
    remove_if_exists /usr/share/hype-store
    remove_if_exists /etc/xdg/quickshell/hype-shell
    remove_if_exists /etc/xdg/quickshell/hypeshell
    remove_if_exists /etc/xdg/quickshell/hype
    remove_if_exists /etc/systemd/user/hypeshell.service
    remove_if_exists /etc/systemd/user/hype-shell.service
    remove_if_exists /usr/local/share/applications/hypeshell.desktop
    remove_if_exists /usr/local/share/applications/hype-shell.desktop
    remove_if_exists /usr/local/share/applications/hype-store.desktop
    remove_if_exists /usr/share/applications/hypeshell.desktop
    remove_if_exists /usr/share/applications/hype-shell.desktop
    remove_if_exists /usr/share/applications/hype-store.desktop
}

install_package_if_available() {
    package="$1"
    if have pacman; then
        sudo_run pacman -S --needed --noconfirm "$package"
    elif have dnf; then
        sudo_run dnf install -y "$package"
    elif have apt-get; then
        sudo_run apt-get update
        sudo_run apt-get install -y "$package"
    elif have zypper; then
        sudo_run zypper --non-interactive install "$package"
    else
        return 1
    fi
}

install_build_dependencies() {
    missing=""
    if ! have go; then
        missing="$missing go"
    fi
    if ! have make; then
        missing="$missing make"
    fi

    [ -n "$missing" ] || return 0

    echo "Installing HypeShell build dependencies:$missing"
    if have pacman; then
        sudo_run pacman -S --needed --noconfirm $missing
    elif have apt-get; then
        packages=""
        for dep in $missing; do
            case "$dep" in
                go) packages="$packages golang-go" ;;
                make) packages="$packages make" ;;
            esac
        done
        sudo_run apt-get update
        sudo_run env DEBIAN_FRONTEND=noninteractive apt-get install -y $packages
    elif have dnf; then
        packages=""
        for dep in $missing; do
            case "$dep" in
                go) packages="$packages golang" ;;
                make) packages="$packages make" ;;
            esac
        done
        sudo_run dnf install -y $packages
    elif have zypper; then
        packages=""
        for dep in $missing; do
            case "$dep" in
                go) packages="$packages go" ;;
                make) packages="$packages make" ;;
            esac
        done
        sudo_run zypper --non-interactive install $packages
    else
        echo "Error: missing build dependencies:$missing" >&2
        echo "Install them with your package manager, then rerun install.sh." >&2
        exit 1
    fi
}

install_quickshell_dependency() {
    if have qs; then
        return 0
    fi

    echo "Installing Quickshell runtime dependency (qs)..."
    if have pacman; then
        if pacman -Si quickshell >/dev/null 2>&1; then
            sudo_run pacman -S --needed --noconfirm quickshell
        elif have yay; then
            run yay -S --needed --noconfirm quickshell-git
        elif have paru; then
            run paru -S --needed --noconfirm quickshell-git
        elif [ "$YES" -eq 0 ]; then
            echo "[dry-run] install quickshell-git with yay or paru if pacman does not provide quickshell"
        else
            echo "Error: Quickshell is required, but the quickshell package was not found in pacman." >&2
            echo "Install an AUR helper and quickshell-git, or install quickshell so the 'qs' command is in PATH, then rerun install.sh." >&2
            exit 1
        fi
    elif have dnf; then
        sudo_run dnf install -y quickshell
    elif have zypper; then
        sudo_run zypper --non-interactive install quickshell
    elif have apt-get; then
        sudo_run apt-get update
        sudo_run env DEBIAN_FRONTEND=noninteractive apt-get install -y quickshell
    else
        echo "Error: Quickshell is required and the 'qs' command is missing from PATH." >&2
        echo "Install Quickshell with your package manager, then rerun install.sh." >&2
        exit 1
    fi
}

install_qt_wayland_dependency() {
    echo "Ensuring Qt Wayland runtime dependency is installed..."
    if have pacman; then
        sudo_run pacman -S --needed --noconfirm qt6-wayland
    elif have dnf; then
        sudo_run dnf install -y qt6-qtwayland
    elif have zypper; then
        sudo_run zypper --non-interactive install qt6-wayland
    elif have apt-get; then
        sudo_run apt-get update
        sudo_run env DEBIAN_FRONTEND=noninteractive apt-get install -y qt6-wayland
    else
        echo "Warning: could not verify Qt Wayland runtime dependency; no supported package manager found." >&2
    fi
}

install_terminal_dependency() {
    if have kitty; then
        return 0
    fi

    echo "Installing kitty terminal dependency..."
    install_package_if_available kitty
}

install_visualizer_dependency() {
    if have cava; then
        return 0
    fi

    echo "Installing cava audio visualizer dependency..."
    install_package_if_available cava || echo "Warning: could not install cava automatically; audio visualizers may be disabled." >&2
}

source_fingerprint() {
    if [ -n "$SOURCE_DIR" ] && [ -d "$SOURCE_DIR/.git" ] && have git; then
        git -C "$SOURCE_DIR" rev-parse --short=12 HEAD 2>/dev/null && return 0
    fi
    echo "unknown"
}

source_remote() {
    if [ -n "$SOURCE_DIR" ] && [ -d "$SOURCE_DIR/.git" ] && have git; then
        git -C "$SOURCE_DIR" config --get remote.origin.url 2>/dev/null && return 0
    fi
    echo "$REPO_URL"
}

file_sha256() {
    file="$1"
    if [ -f "$file" ] && have sha256sum; then
        sha256sum "$file" | awk '{print $1}'
        return 0
    fi
    echo "missing"
}

greetd_command_line() {
    if [ -r /etc/greetd/config.toml ]; then
        grep -E '^[[:space:]]*command[[:space:]]*=' /etc/greetd/config.toml | tail -n 1 || true
    fi
}

write_install_fingerprint() {
    install_status="${1:-complete}"
    fingerprint="$(source_fingerprint)"
    remote="$(source_remote)"
    greetd_command="$(greetd_command_line)"
    tmp_file="$(mktemp)"

    {
        echo "HypeShell install fingerprint"
        echo "installer_build_id=$INSTALLER_BUILD_ID"
        echo "install_status=$install_status"
        echo "installed_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "source_remote=$remote"
        echo "source_branch=$BRANCH"
        echo "source_commit=$fingerprint"
        echo "source_dir=${SOURCE_DIR:-}"
        echo "prefix=$PREFIX"
        echo "hype_binary=$(command -v hype 2>/dev/null || true)"
        echo "shell_path=$PREFIX/share/quickshell/hype"
        echo "greeter_wrapper_local=/usr/local/bin/hype-greeter sha256=$(file_sha256 /usr/local/bin/hype-greeter)"
        echo "greeter_wrapper_system=/usr/bin/hype-greeter sha256=$(file_sha256 /usr/bin/hype-greeter)"
        echo "greetd_command=${greetd_command:-missing}"
    } > "$tmp_file"

    sudo_run install -D -m 644 "$tmp_file" "$FINGERPRINT_PATH"
    rm -f "$tmp_file"

    echo
    echo "HypeShell install fingerprint:"
    echo "  installer: $INSTALLER_BUILD_ID"
    echo "  status: $install_status"
    echo "  commit: $fingerprint"
    echo "  file:   $FINGERPRINT_PATH"
    echo "  greetd: ${greetd_command:-missing}"
}

write_failure_fingerprint() {
    exit_code="$?"
    echo "Installer failed with exit code $exit_code; writing failure fingerprint..." >&2
    write_install_fingerprint "failed:$exit_code" || true
}

install_greetd_if_needed() {
    if have greetd || [ -x /usr/sbin/greetd ] || [ -x /sbin/greetd ]; then
        return 0
    fi

    echo "Installing greetd only. No legacy upstream shell packages will be installed."
    install_package_if_available greetd
}

install_source_dependency() {
    [ "$INSTALL_METHOD" = "source" ] || return 0
    have git && return 0

    echo "Installing git source dependency..."
    if ! install_package_if_available git; then
        echo "Error: git is required to clone $REPO_URL." >&2
        echo "Install git with your package manager, then rerun install.sh." >&2
        exit 1
    fi
}

prepare_source() {
    if [ -n "$SOURCE_DIR" ]; then
        if have realpath; then
            SOURCE_DIR="$(realpath "$SOURCE_DIR")"
        else
            SOURCE_DIR="$(cd "$SOURCE_DIR" && pwd -P)"
        fi
        if [ ! -f "$SOURCE_DIR/quickshell/shell.qml" ] || [ ! -f "$SOURCE_DIR/core/Makefile" ]; then
            echo "Error: --source does not look like a HypeShell checkout: $SOURCE_DIR" >&2
            exit 1
        fi
        return 0
    fi

    if ! have git; then
        if [ "$YES" -eq 0 ]; then
            SOURCE_DIR="$WORK_DIR/Hype"
            run mkdir -p "$WORK_DIR"
            run git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$SOURCE_DIR"
            return 0
        fi
        echo "Error: git is required to clone $REPO_URL." >&2
        exit 1
    fi

    SOURCE_DIR="$WORK_DIR/Hype"
    run mkdir -p "$WORK_DIR"
    run git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$SOURCE_DIR"
}

verify_hypeshell_source_payload() {
    if [ "$YES" -eq 0 ] && [ ! -d "$SOURCE_DIR" ]; then
        echo "Would verify HypeShell source payload before removing upstream packages."
        return 0
    fi

    missing=0
    for required in \
        "$SOURCE_DIR/quickshell/shell.qml" \
        "$SOURCE_DIR/core/Makefile" \
        "$SOURCE_DIR/core/internal/config/embedded/hyprland.conf" \
        "$SOURCE_DIR/core/internal/config/embedded/hypr-colors.conf" \
        "$SOURCE_DIR/core/internal/config/embedded/hypr-layout.conf" \
        "$SOURCE_DIR/core/internal/config/embedded/hypr-binds.conf" \
        "$SOURCE_DIR/quickshell/Modules/Greetd/assets/hype-greeter" \
        "$SOURCE_DIR/assets/sessions/hypeshell-hyprland.desktop" \
        "$SOURCE_DIR/assets/sessions/hypeshell-hyprland-session"; do
        if [ ! -f "$required" ]; then
            echo "Missing required HypeShell payload: $required" >&2
            missing=1
        fi
    done

    if [ "$missing" -ne 0 ]; then
        echo "Error: refusing to remove upstream packages until the HypeShell replacement payload exists." >&2
        exit 1
    fi
}

install_hyprland_if_needed() {
    if have Hyprland || have hyprland; then
        return 0
    fi

    echo "Installing Hyprland compositor as an OS dependency."
    install_package_if_available hyprland
}

protect_hyprland_dependency() {
    if [ "$INSTALL_HYPRLAND_SESSION" -eq 0 ] || [ "$SKIP_PACKAGE_REMOVAL" -eq 1 ]; then
        return 0
    fi

    if have pacman && pacman -Q hyprland >/dev/null 2>&1; then
        sudo_run pacman -D --asexplicit hyprland
    fi
}

install_hyprland_session() {
    if [ "$INSTALL_HYPRLAND_SESSION" -eq 0 ] || [ "$SKIP_INSTALL" -eq 1 ]; then
        return 0
    fi

    if [ "$INSTALL_METHOD" != "source" ]; then
        echo "Skipping HypeShell Hyprland session because package install method was requested."
        return 0
    fi

    prepare_source
    verify_hypeshell_source_payload
    install_hyprland_if_needed

    defaults_dir="$PREFIX/share/hypeshell/hyprland"
    sudo_run install -D -m 755 "$SOURCE_DIR/assets/sessions/hypeshell-hyprland-session" "$PREFIX/bin/hypeshell-hyprland-session"
    sudo_run sed -i 's/\r$//' "$PREFIX/bin/hypeshell-hyprland-session" || true
    sudo_run install -D -m 644 "$SOURCE_DIR/assets/sessions/hypeshell-hyprland.desktop" "$PREFIX/share/wayland-sessions/hypeshell-hyprland.desktop"
    sudo_run install -D -m 644 "$SOURCE_DIR/core/internal/config/embedded/hyprland.conf" "$defaults_dir/hyprland.conf"
    sudo_run install -D -m 644 "$SOURCE_DIR/core/internal/config/embedded/hypr-colors.conf" "$defaults_dir/hype/colors.conf"
    sudo_run install -D -m 644 "$SOURCE_DIR/core/internal/config/embedded/hypr-layout.conf" "$defaults_dir/hype/layout.conf"
    sudo_run install -D -m 644 "$SOURCE_DIR/core/internal/config/embedded/hypr-binds.conf" "$defaults_dir/hype/binds.conf"

    sudo_run install -D -m 644 /dev/null "$defaults_dir/hype/outputs.conf"
    sudo_run install -D -m 644 /dev/null "$defaults_dir/hype/cursor.conf"
    sudo_run install -D -m 644 /dev/null "$defaults_dir/hype/windowrules.conf"
}

ensure_hyprland_shell_startup() {
    [ "$INSTALL_HYPRLAND_SESSION" -eq 1 ] || return 0

    config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
    config_file="$config_dir/hyprland.conf"
    hype_config_dir="$config_dir/hype"
    legacy_config_dir="$config_dir/hype"
    startup_line="exec-once = systemctl --user start hype.service || hype run"

    if [ "$YES" -eq 0 ]; then
        run mkdir -p "$config_dir"
        echo "[dry-run] ensure $config_file starts HypeShell with: $startup_line"
        return 0
    fi

    mkdir -p "$config_dir"
    mkdir -p "$hype_config_dir"
    if [ -d "$legacy_config_dir" ]; then
        for config_name in colors.conf outputs.conf layout.conf cursor.conf binds.conf windowrules.conf; do
            if [ -e "$legacy_config_dir/$config_name" ] && [ ! -e "$hype_config_dir/$config_name" ]; then
                cp "$legacy_config_dir/$config_name" "$hype_config_dir/$config_name"
            fi
        done
    fi

    if [ ! -s "$config_file" ]; then
        default_config="$PREFIX/share/hypeshell/hyprland/hyprland.conf"
        if [ -r "$default_config" ]; then
            cp "$default_config" "$config_file"
        elif [ -n "$SOURCE_DIR" ] && [ -r "$SOURCE_DIR/core/internal/config/embedded/hyprland.conf" ]; then
            cp "$SOURCE_DIR/core/internal/config/embedded/hyprland.conf" "$config_file"
        fi
    fi

    if [ -f "$config_file" ] && grep -q 'source = \./hype/' "$config_file"; then
        cp "$config_file" "$config_file.hypeshell-pre-paths.bak"
        sed -i -e 's#source = \./hype/#source = ./hype/#g' "$config_file"
    fi

    if [ -f "$hype_config_dir/binds.conf" ] && { grep -q '{{TERMINAL_COMMAND}}' "$hype_config_dir/binds.conf" || grep -q 'hype ipc call' "$hype_config_dir/binds.conf" || grep -q 'hype clipboard copy' "$hype_config_dir/binds.conf"; }; then
        cp "$hype_config_dir/binds.conf" "$hype_config_dir/binds.conf.hypeshell-pre-command-repair.bak"
        sed -i \
            -e 's/{{TERMINAL_COMMAND}}/kitty/g' \
            -e 's/hype ipc call/hype ipc call/g' \
            -e 's/hype clipboard copy/hype clipboard copy/g' \
            "$hype_config_dir/binds.conf"
    fi

    if [ -f "$config_file" ] && ! grep -Eq '(^|[[:space:]])(hype run|hype\.service)' "$config_file"; then
        cp "$config_file" "$config_file.hypeshell-pre-startup.bak"
        if grep -Eq '(^|[[:space:]])(hype run|hype\.service)' "$config_file"; then
            sed -i \
                -e 's/systemctl --user start hype\.service/systemctl --user start hype.service/g' \
                -e 's/\bhype run\b/hype run/g' \
                -e 's#source = \./hype/#source = ./hype/#g' \
                "$config_file"
            return 0
        fi
        {
            printf '\n# HypeShell startup\n'
            printf '%s\n' "$startup_line"
        } >> "$config_file"
    fi
}

install_hype() {
    if [ "$SKIP_INSTALL" -eq 1 ]; then
        echo "Skipping Hype install."
        return 0
    fi

    install_source_dependency
    prepare_source

    install_build_dependencies
    install_quickshell_dependency
    install_qt_wayland_dependency
    install_terminal_dependency
    install_visualizer_dependency

    run make -C "$SOURCE_DIR" build
    sudo_run make -C "$SOURCE_DIR" PREFIX="$PREFIX" install
    run systemctl --user daemon-reload || true
}

restart_hype_service() {
    [ "$YES" -eq 1 ] || {
        echo "[dry-run] restart HypeShell user service after install/update"
        return 0
    }

    run systemctl --user daemon-reload || true

    if [ -n "${WAYLAND_DISPLAY:-}" ]; then
        run systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS || true
    fi

    if ! systemctl --user cat hype.service >/dev/null 2>&1; then
        echo "Warning: hype.service is not installed; start HypeShell manually with 'hype run'." >&2
        return 0
    fi

    run systemctl --user enable hype.service >/dev/null 2>&1 || true

    if [ -z "${WAYLAND_DISPLAY:-}" ]; then
        echo "HypeShell service is enabled. It will start from the Hyprland session."
        return 0
    fi

    if systemctl --user is-active --quiet hype.service; then
        echo "Scheduling HypeShell user service restart..."
        restart_script="$WORK_DIR/restart-hype-service.sh"
        cat > "$restart_script" <<EOF
#!/bin/sh
sleep 2
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}"
export DISPLAY="${DISPLAY:-}"
export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-}"
export XDG_SESSION_DESKTOP="${XDG_SESSION_DESKTOP:-}"
export XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-}"
export HYPRLAND_INSTANCE_SIGNATURE="${HYPRLAND_INSTANCE_SIGNATURE:-}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-}"
systemctl --user daemon-reload >/dev/null 2>&1 || true
systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS >/dev/null 2>&1 || true
if systemctl --user restart hype.service >/dev/null 2>&1; then
    sleep 2
    if systemctl --user is-active --quiet hype.service; then
        exit 0
    fi
fi
systemctl --user reset-failed hype.service >/dev/null 2>&1 || true
if systemctl --user start hype.service >/dev/null 2>&1; then
    sleep 2
    if systemctl --user is-active --quiet hype.service; then
        exit 0
    fi
fi
if [ -n "\${WAYLAND_DISPLAY:-}" ] && [ -x "$PREFIX/bin/hype" ]; then
    nohup "$PREFIX/bin/hype" run --session >/tmp/hypeshell-update-restart.log 2>&1 &
    exit 0
fi
systemctl --user reset-failed hype.service >/dev/null 2>&1 || true
exit 1
EOF
        chmod +x "$restart_script"
        if command -v systemd-run >/dev/null 2>&1; then
            if ! systemd-run --user --unit=hypeshell-post-update-restart --collect "$restart_script" >/dev/null 2>&1; then
                nohup "$restart_script" >/dev/null 2>&1 &
            fi
        else
            nohup "$restart_script" >/dev/null 2>&1 &
        fi
    else
        echo "Starting HypeShell user service..."
        run systemctl --user start hype.service || echo "Warning: failed to start hype.service; run 'hype run' from Hyprland to debug." >&2
    fi
}

refresh_installed_registry_assets() {
    [ "$SKIP_INSTALL" -eq 0 ] || return 0

    if [ "$YES" -eq 0 ]; then
        echo "[dry-run] refresh installed Hype themes and plugins from HypeRegistry"
        return 0
    fi

    if ! have git; then
        echo "Warning: git is not available; skipping HypeRegistry theme/plugin refresh." >&2
        return 0
    fi

    registry_dir="$WORK_DIR/HypeRegistry"
    echo "Refreshing installed Hype themes and plugins from HypeRegistry..."
    echo "Existing local-only theme/plugin directories are preserved."
    if ! git clone --depth 1 https://github.com/acarlton5/HypeRegistry.git "$registry_dir" >/dev/null 2>&1; then
        echo "Warning: could not clone HypeRegistry; installed themes/plugins were not refreshed." >&2
        return 0
    fi

    theme_root="${XDG_CONFIG_HOME:-$HOME/.config}/HypeShell/themes"
    if [ -d "$theme_root" ]; then
        for theme_dir in "$theme_root"/*; do
            [ -f "$theme_dir/theme.json" ] || continue
            theme_id="$(basename "$theme_dir")"
            registry_theme="$registry_dir/themes/$theme_id"
            [ -d "$registry_theme" ] || continue
            echo "Updating installed theme: $theme_id"
            cp -a "$registry_theme"/. "$theme_dir"/
        done
    fi

    hype_cmd="$PREFIX/bin/hype"
    if [ ! -x "$hype_cmd" ]; then
        hype_cmd="$(command -v hype || true)"
    fi

    plugin_root="${XDG_CONFIG_HOME:-$HOME/.config}/HypeShell/plugins"
    if [ -n "$hype_cmd" ] && [ -d "$plugin_root" ]; then
        for plugin_dir in "$plugin_root"/*; do
            [ -f "$plugin_dir/plugin.json" ] || continue
            plugin_id="$(basename "$plugin_dir")"
            echo "Updating installed plugin: $plugin_id"
            "$hype_cmd" plugins update "$plugin_id" >/dev/null 2>&1 || echo "Warning: could not update plugin $plugin_id" >&2
        done
    fi
}

install_greeter_wrapper_from_source() {
    [ "$INSTALL_METHOD" = "source" ] || return 0

    if [ "$YES" -eq 0 ]; then
        run sudo install -D -m 755 "$PREFIX/share/quickshell/hype/Modules/Greetd/assets/hype-greeter" /usr/local/bin/hype-greeter
        return 0
    fi

    wrapper_src=""
    for candidate in \
        "$PREFIX/share/quickshell/hype/Modules/Greetd/assets/hype-greeter" \
        "$SOURCE_DIR/quickshell/Modules/Greetd/assets/hype-greeter"
    do
        if [ -f "$candidate" ]; then
            wrapper_src="$candidate"
            break
        fi
    done

    if [ -z "$wrapper_src" ]; then
        echo "Error: hype-greeter wrapper not found after source install." >&2
        echo "Expected it at $PREFIX/share/quickshell/hype/Modules/Greetd/assets/hype-greeter" >&2
        exit 1
    fi

    sudo_run install -D -m 755 "$wrapper_src" /usr/local/bin/hype-greeter
    sudo_run install -D -m 755 "$wrapper_src" /usr/bin/hype-greeter
    sudo_run sed -i 's/\r$//' /usr/local/bin/hype-greeter /usr/bin/hype-greeter || true
    sudo_run rm -f /usr/local/bin/dank-greeter /usr/bin/dank-greeter /usr/local/bin/dms-greeter /usr/bin/dms-greeter
}

detect_greeter_user() {
    if [ -r /etc/greetd/config.toml ]; then
        configured_user="$(awk -F'"' '/^[[:space:]]*user[[:space:]]*=/{print $2; exit}' /etc/greetd/config.toml)"
        if [ -n "$configured_user" ] && getent passwd "$configured_user" >/dev/null 2>&1; then
            echo "$configured_user"
            return 0
        fi
    fi

    for candidate in greeter greetd _greeter; do
        if getent passwd "$candidate" >/dev/null 2>&1; then
            echo "$candidate"
            return 0
        fi
    done

    echo "greeter"
}

force_repair_greetd_config() {
    [ "$INSTALL_GREETER" -eq 1 ] || return 0
    [ "$INSTALL_METHOD" = "source" ] || return 0

    greeter_user="$(detect_greeter_user)"
    wrapper="/usr/local/bin/hype-greeter"
    shell_path="$PREFIX/share/quickshell/hype"
    command_value="$wrapper --command hyprland --cache-dir /var/cache/hype-greeter -p $shell_path"
    tmp_file="$(mktemp)"

    cat > "$tmp_file" <<EOF
[terminal]
vt = 1

[default_session]
user = "$greeter_user"
command = "$command_value"
EOF

    if [ -f /etc/greetd/config.toml ]; then
        sudo_run cp /etc/greetd/config.toml "/etc/greetd/config.toml.hypeshell-pre-force-repair-$TIMESTAMP"
    fi
    sudo_run install -D -m 644 "$tmp_file" /etc/greetd/config.toml
    rm -f "$tmp_file"

    sudo_run mkdir -p /var/cache/hype-greeter
    if getent group greeter >/dev/null 2>&1; then
        sudo_run chgrp greeter /var/cache/hype-greeter || true
    fi
    sudo_run chmod 2770 /var/cache/hype-greeter || true

    echo "Forced greetd command:"
    echo "  command = \"$command_value\""
}

install_greeter() {
    if [ "$INSTALL_GREETER" -eq 0 ]; then
        return 0
    fi

    if [ "$YES" -eq 0 ]; then
        echo "Would install/configure HypeShell greeter for Hyprland. This replaces SDDM/GDM/LightDM with greetd."
        if [ "$INSTALL_METHOD" = "source" ]; then
            run sudo install-package greetd
            install_greeter_wrapper_from_source
            run hype greeter enable --yes
            run hype greeter sync --yes
        else
            run hype greeter install --yes
            run hype greeter sync --yes
        fi
        run hype greeter status
        return 0
    fi

    if ! have hype; then
        echo "Error: hype command is not available; cannot install HypeShell greeter." >&2
        echo "Install HypeShell first, then rerun with --skip-install --install-greeter." >&2
        exit 1
    fi

    echo "Installing/configuring HypeShell greeter for Hyprland. This replaces SDDM/GDM/LightDM with greetd."
    if [ "$INSTALL_METHOD" = "source" ]; then
        install_greetd_if_needed
        install_greeter_wrapper_from_source
        run hype greeter enable --yes || echo "Warning: hype greeter enable failed; forcing greetd config repair."
        run hype greeter sync --yes || echo "Warning: hype greeter sync failed; forcing greetd config repair."
        force_repair_greetd_config
    else
        run hype greeter install --yes
        run hype greeter sync --yes
    fi
    run hype greeter status || true
}

clean_display_manager() {
    if [ "$CLEAN_DISPLAY_MANAGER" -eq 0 ]; then
        return 0
    fi

    if [ "$INSTALL_GREETER" -eq 0 ]; then
        echo "Error: display-manager cleanup requires greeter setup so greetd is configured first." >&2
        exit 1
    fi

    if have pacman && pacman -Q sddm >/dev/null 2>&1; then
        sudo_run pacman -Rns --noconfirm sddm
        NEEDS_REBOOT=1
    elif have rpm && rpm -q sddm >/dev/null 2>&1; then
        if have dnf; then
            sudo_run dnf remove -y sddm
        elif have zypper; then
            sudo_run zypper --non-interactive remove sddm
        else
            sudo_run rpm -e sddm
        fi
        NEEDS_REBOOT=1
    elif have dpkg-query && dpkg-query -W -f='${Status}' sddm 2>/dev/null | grep -q "install ok installed"; then
        sudo_run apt-get remove -y sddm
        NEEDS_REBOOT=1
    else
        echo "sddm package not installed or no supported package manager found."
    fi
}

system_reboot_required() {
    [ "$NEEDS_REBOOT" -eq 1 ] && return 0
    [ -f /run/reboot-required ] && return 0
    [ -f /var/run/reboot-required ] && return 0
    return 1
}

maybe_reboot_if_needed() {
    [ "$YES" -eq 1 ] || return 0
    [ "$REBOOT_IF_NEEDED" -eq 1 ] || return 0
    system_reboot_required || return 0

    echo
    echo "A reboot is recommended to finish applying HypeShell system changes."
    if [ "$AUTO_REBOOT_IF_NEEDED" -eq 1 ]; then
        echo "Rebooting now..."
        sudo_run systemctl reboot
        return 0
    fi

    if [ -t 0 ]; then
        printf 'Reboot now? [y/N] '
        read -r reply
        case "$reply" in
            y|Y|yes|YES)
                sudo_run systemctl reboot
                ;;
            *)
                echo "Reboot skipped. Reboot manually when ready."
                ;;
        esac
    else
        echo "Run 'sudo systemctl reboot' when ready."
    fi
}

main() {
    trap write_failure_fingerprint ERR

    if [ "$YES" -eq 0 ]; then
        cat <<EOF
Dry run only. Re-run without --dry-run to make changes.

This will:
  - stop/disable legacy HypeShell user services
  - remove known old HypeShell binaries, service files, desktop files, and shell paths
  - move old user config/state/cache into:
    $BACKUP_DIR
  - build and install Hype from:
    ${SOURCE_DIR:-$REPO_URL}
  - install Quickshell if the "qs" command is missing
  - install the new system command as "hype" under:
    $PREFIX/bin/hype
  - install method:
    $INSTALL_METHOD
  - install HypeShell greeter / replace SDDM with greetd:
    $INSTALL_GREETER
  - install HypeShell-owned Hyprland session/config:
    $INSTALL_HYPRLAND_SESSION
  - remove sddm package after greeter setup:
    $CLEAN_DISPLAY_MANAGER

EOF
    else
        if [ "$UPDATE_EXISTING" -eq 0 ] && existing_hypeshell_install_detected; then
            echo "Error: an existing HypeShell install was detected." >&2
            echo "Run this installer with --update to repair/update an existing install." >&2
            exit 2
        fi
        mkdir -p "$BACKUP_DIR"
    fi

    write_install_fingerprint "started"

    install_source_dependency

    if [ "$INSTALL_METHOD" = "source" ] && { [ "$REMOVE_HYPE_PACKAGES" -eq 1 ] || [ "$INSTALL_HYPRLAND_SESSION" -eq 1 ]; }; then
        prepare_source
        verify_hypeshell_source_payload
    fi

    write_install_fingerprint "source-ready"

    stop_disable_user_units
    kill_legacy_processes
    protect_hyprland_dependency
    remove_legacy_packages
    remove_legacy_user_artifacts
    remove_legacy_system_artifacts
    install_hype
    install_hyprland_session
    refresh_installed_registry_assets
    ensure_hyprland_shell_startup
    install_greeter
    clean_display_manager
    write_install_fingerprint "complete"
    restart_hype_service
    trap - ERR

    if [ "$YES" -eq 1 ]; then
        echo
        if [ "$UPDATE_EXISTING" -eq 1 ]; then
            echo "HypeShell update complete."
        else
            echo "HypeShell install complete."
        fi
        if [ "$PURGE_USER_DATA" -eq 0 ]; then
            echo "Legacy user data backup: $BACKUP_DIR"
        fi
        echo "HypeShell service has been started/restarted."
        maybe_reboot_if_needed
    else
        echo
        echo "Dry run complete. No changes were made."
    fi
}

main "$@"
