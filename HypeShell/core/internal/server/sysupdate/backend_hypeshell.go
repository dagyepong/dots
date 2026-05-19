package sysupdate

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

const (
	hypeShellRepoURL = "https://github.com/acarlton5/HypeShell.git"
)

func init() {
	RegisterOverlayBackend(func() Backend { return &hypeShellBackend{} })
}

type hypeShellBackend struct{}

func (hypeShellBackend) ID() string             { return "hypeshell" }
func (hypeShellBackend) DisplayName() string    { return "HypeShell" }
func (hypeShellBackend) Repo() RepoKind         { return RepoHypeShell }
func (hypeShellBackend) NeedsAuth() bool        { return true }
func (hypeShellBackend) RunsInTerminal() bool {
	return false
}
func (hypeShellBackend) IsAvailable(ctx context.Context) bool {
	return commandExists("git") && (commandExists("hype") || installedHypeShellCommit() != "")
}

func (hypeShellBackend) CheckUpdates(ctx context.Context) ([]Package, error) {
	latest, err := latestHypeShellCommit(ctx)
	if err != nil || latest == "" {
		return nil, nil
	}

	installed := installedHypeShellCommit()
	if installed != "" && shortCommit(installed) == shortCommit(latest) {
		return nil, nil
	}

	from := shortCommit(installed)
	if from == "" {
		from = "unknown"
	}

	return []Package{{
		Name:         "HypeShell",
		Repo:         RepoHypeShell,
		Backend:      "hypeshell",
		FromVersion:  from,
		ToVersion:    shortCommit(latest),
		Ref:          "main",
		ChangelogURL: "https://github.com/acarlton5/HypeShell/commits/main",
	}}, nil
}

func (b hypeShellBackend) Upgrade(ctx context.Context, opts UpgradeOptions, onLine func(string)) error {
	realUID := fmt.Sprintf("%d", os.Getuid())
	realUser := os.Getenv("USER")
	realHome := os.Getenv("HOME")
	realXdg := os.Getenv("XDG_RUNTIME_DIR")
	realDbus := os.Getenv("DBUS_SESSION_BUS_ADDRESS")
	cmd := hypeShellSelfUpdateScript(realUID, realUser, realHome, realXdg, realDbus)
	if onLine != nil {
		onLine("$ hype update --self")
		onLine("Updating HypeShell from GitHub main")
	}

	if opts.Password != "" {
		sudoArgv := []string{"sudo", "-S", "bash", "-c", cmd}
		return Run(ctx, sudoArgv, RunOptions{
			OnLine: onLine,
			Stdin:  opts.Password + "\n",
		})
	}

	if b.RunsInTerminal() {
		term := findTerminal(opts.Terminal)
		if term == "" {
			return fmt.Errorf("no terminal found (pick one in HypeShell settings, set $TERMINAL, or install kitty/ghostty/foot/alacritty)")
		}
		sudoCmd := "sudo bash -c " + shellQuote(cmd)
		title := "HypeShell Self-Update"
		return Run(ctx, wrapInTerminal(term, title, sudoCmd), RunOptions{OnLine: onLine})
	}

	bashPath, err := exec.LookPath("bash")
	if err != nil {
		bashPath = "/usr/bin/bash"
	}
	return Run(ctx, []string{"pkexec", bashPath, "-c", cmd}, RunOptions{OnLine: onLine})
}

func hypeShellSelfUpdateScript(realUID, realUser, realHome, realXdg, realDbus string) string {
	userPath := os.Getenv("PATH")
	if userPath == "" {
		userPath = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
	}
	return fmt.Sprintf(`set -euo pipefail
export PATH=%s:"$PATH"
export GOGC=30
export GOMAXPROCS=1
export GOMEMLIMIT=768MiB

invoking_uid="${SUDO_UID:-${PKEXEC_UID:-%s}}"
if [ -n "$invoking_uid" ] && [ "$invoking_uid" != "0" ]; then
    update_user=$(id -un "$invoking_uid")
    update_home=$(getent passwd "$invoking_uid" | cut -d: -f6)
else
    update_user="%s"
    update_home="%s"
    invoking_uid="%s"
fi

cache_dir="$update_home/.cache/hypeshell-update"
mkdir -p "$cache_dir"
tmp="$(mktemp -d "$cache_dir/hypeshell-self-update-XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

# Fallback values for XDG and DBus runtime if they need to be populated in the reload block
xdg_runtime="%s"
dbus_bus="%s"
if [ -z "$xdg_runtime" ]; then
    xdg_runtime="/run/user/$invoking_uid"
fi
if [ -z "$dbus_bus" ]; then
    dbus_bus="unix:path=/run/user/$invoking_uid/bus"
fi

# Pre-locate and resolve invoking user's Go compiler path if not in default elevated PATH
user_go=""
if [ -n "$invoking_uid" ]; then
    user_go="$(runuser -u "$update_user" -- env HOME="$update_home" bash -lc "command -v go" 2>/dev/null | grep -E '^/' | tail -n1 || true)"
fi
if [ -z "$user_go" ]; then
    user_go="$(command -v go 2>/dev/null || true)"
fi
if [ -n "$user_go" ]; then
    go_dir="$(dirname "$user_go")"
    export PATH="$go_dir:$PATH"
fi

echo "Cloning HypeShell main..."
git clone --depth 1 --branch main %s "$tmp/source"
commit="$(git -C "$tmp/source" rev-parse HEAD)"

echo "Tidying Go modules..."
(cd "$tmp/source/core" && go mod tidy || true)

echo "Building HypeShell ${commit:0:12}..."
make -C "$tmp/source" build

cat > "$tmp/install-fingerprint" <<EOF
status=success
installed_at=$(date -u +%%Y-%%m-%%dT%%H:%%M:%%SZ)
source_remote=%s
source_branch=main
source_commit=$commit
installer_build=hype-shade-self-update-v2
EOF

echo "Installing HypeShell..."
make -C "$tmp/source" PREFIX="/usr/local" install
install -D -m 644 "$tmp/install-fingerprint" "/usr/local/share/hypeshell/install-fingerprint"

echo "HypeShell self-update complete. Reloading service in 2 seconds..."
if [ -n "$invoking_uid" ]; then
    (
        sleep 2
        runuser -u "$update_user" -- env HOME="$update_home" XDG_RUNTIME_DIR="$xdg_runtime" DBUS_SESSION_BUS_ADDRESS="$dbus_bus" systemctl --user daemon-reload || true
        runuser -u "$update_user" -- env HOME="$update_home" XDG_RUNTIME_DIR="$xdg_runtime" DBUS_SESSION_BUS_ADDRESS="$dbus_bus" systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS || true
        if ! runuser -u "$update_user" -- env HOME="$update_home" XDG_RUNTIME_DIR="$xdg_runtime" DBUS_SESSION_BUS_ADDRESS="$dbus_bus" systemctl --user restart hype.service && ! runuser -u "$update_user" -- env HOME="$update_home" XDG_RUNTIME_DIR="$xdg_runtime" DBUS_SESSION_BUS_ADDRESS="$dbus_bus" systemctl --user start hype.service; then
            runuser -u "$update_user" -- env HOME="$update_home" XDG_RUNTIME_DIR="$xdg_runtime" DBUS_SESSION_BUS_ADDRESS="$dbus_bus" nohup /usr/local/bin/hype run --session >/tmp/hypeshell-update-restart.log 2>&1 &
        fi
    ) >/dev/null 2>&1 &
else
    (
        sleep 2
        systemctl --user daemon-reload || true
        systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS || true
        if ! systemctl --user restart hype.service && ! systemctl --user start hype.service; then
            nohup /usr/local/bin/hype run --session >/tmp/hypeshell-update-restart.log 2>&1 &
        fi
    ) >/dev/null 2>&1 &
fi
`,
		shellQuote(userPath),
		shellQuote(realUID),
		shellQuote(realUser),
		shellQuote(realHome),
		shellQuote(realUID),
		shellQuote(realXdg),
		shellQuote(realDbus),
		shellQuote(hypeShellRepoURL),
		shellQuote(hypeShellRepoURL),
	)
}

func shellQuote(value string) string {
	return "'" + strings.ReplaceAll(value, "'", "'\\''") + "'"
}

func latestHypeShellCommit(ctx context.Context) (string, error) {
	out, err := Capture(ctx, []string{"git", "ls-remote", hypeShellRepoURL, "refs/heads/main"})
	if err != nil {
		return "", err
	}
	fields := strings.Fields(out)
	if len(fields) == 0 {
		return "", nil
	}
	return fields[0], nil
}

func installedHypeShellCommit() string {
	for _, path := range []string{
		"/usr/local/share/hypeshell/install-fingerprint",
		"/usr/share/hypeshell/install-fingerprint",
	} {
		commit := readFingerprintCommit(path)
		if commit != "" {
			return commit
		}
	}
	return ""
}

func readFingerprintCommit(path string) string {
	f, err := os.Open(path)
	if err != nil {
		return ""
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		value, ok := strings.CutPrefix(line, "source_commit=")
		if !ok {
			continue
		}
		value = strings.TrimSpace(value)
		if value == "" || value == "unknown" || strings.HasPrefix(value, "failed:") {
			return ""
		}
		return value
	}
	return ""
}

func shortCommit(commit string) string {
	commit = strings.TrimSpace(commit)
	if len(commit) > 12 {
		return commit[:12]
	}
	return commit
}
