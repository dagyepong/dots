package sysupdate

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"
	"sync"

	"github.com/acarlton5/HypeShell/core/internal/privesc"
)

type RunOptions struct {
	Env         []string
	OnLine      func(string)
	AttachStdio bool
	Stdin       string
}

func Run(ctx context.Context, argv []string, opts RunOptions) error {
	if len(argv) == 0 {
		return fmt.Errorf("sysupdate.Run: empty argv")
	}

	cmd := exec.CommandContext(ctx, argv[0], argv[1:]...)
	cmd.Env = graphicalEnviron()
	if len(opts.Env) > 0 {
		cmd.Env = append(cmd.Env, opts.Env...)
	}
	if opts.AttachStdio {
		cmd.Cancel = func() error {
			if cmd.Process == nil {
				return nil
			}
			return cmd.Process.Kill()
		}
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if opts.Stdin != "" {
			cmd.Stdin = strings.NewReader(opts.Stdin)
		}
		return cmd.Run()
	}

	cmd.Cancel = func() error {
		if cmd.Process == nil {
			return nil
		}
		return cmd.Process.Kill()
	}

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return err
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return err
	}

	if opts.Stdin != "" {
		cmd.Stdin = strings.NewReader(opts.Stdin)
	}

	if err := cmd.Start(); err != nil {
		return err
	}

	var wg sync.WaitGroup
	wg.Add(2)
	go pump(stdout, opts.OnLine, &wg)
	go pump(stderr, opts.OnLine, &wg)
	wg.Wait()

	return cmd.Wait()
}

func pump(r io.Reader, onLine func(string), wg *sync.WaitGroup) {
	defer wg.Done()
	if onLine == nil {
		_, _ = io.Copy(io.Discard, r)
		return
	}
	scanner := bufio.NewScanner(r)
	scanner.Buffer(make([]byte, 64*1024), 1024*1024)
	for scanner.Scan() {
		onLine(scanner.Text())
	}
}

func Capture(ctx context.Context, argv []string) (string, error) {
	if len(argv) == 0 {
		return "", fmt.Errorf("sysupdate.Capture: empty argv")
	}
	cmd := exec.CommandContext(ctx, argv[0], argv[1:]...)
	out, err := cmd.Output()
	return string(out), err
}

// privescBin returns the binary to use for privilege escalation.
// When useSudo is true it auto-detects the best available tool (sudo/doas/run0).
// When false it falls back to pkexec for GUI callers.
func privescBin(useSudo bool) string {
	if useSudo {
		if t, err := privesc.Detect(); err == nil {
			return t.Name()
		}
	}
	return "pkexec"
}

func findTerminal(override string) string {
	if override != "" && commandExists(override) {
		return override
	}
	if t := os.Getenv("TERMINAL"); t != "" && commandExists(t) {
		return t
	}
	for _, t := range []string{"ghostty", "kitty", "foot", "alacritty", "wezterm", "konsole", "gnome-terminal", "xterm"} {
		if commandExists(t) {
			return t
		}
	}
	return ""
}

func wrapInTerminal(term, title, shellCmd string) []string {
	const appID = "hypeshell-update"

	displayCmd := shellCmd
	if len(displayCmd) > 80 || strings.Contains(displayCmd, "\n") {
		displayCmd = "hype update --self"
	}

	banner := fmt.Sprintf(
		`printf '\033[1;36m=== %%s ===\033[0m\n' %s; printf '\033[2m$ %%s\033[0m\n' %s; printf '\033[33mYou may be prompted for your sudo password to apply system updates.\033[0m\n\n'`,
		shellQuote(title),
		shellQuote(displayCmd),
	)
	closer := `printf '\n\033[1;32m=== Done. Press Enter to close. ===\033[0m\n'; read`
	export := `export SUDO_PROMPT="[HypeShell] sudo password for %u: "; `
	full := export + banner + "; " + shellCmd + "; " + closer

	var argv []string
	switch term {
	case "kitty":
		argv = []string{
			term,
			"--class", appID,
			"-T", title,
			"-o", "hide_window_decorations=yes",
			"-o", "remember_window_size=no",
			"-o", "initial_width=680",
			"-o", "initial_height=420",
			"-o", "font_size=11",
			"-o", "background=#0c0f14",
			"-o", "foreground=#cdd6f4",
			"-o", "window_padding_width=15",
			"-e", "sh", "-c", full,
		}
	case "alacritty":
		argv = []string{term, "--class", appID, "-T", title, "-e", "sh", "-c", full}
	case "foot":
		argv = []string{term, "--app-id=" + appID, "--title=" + title, "-e", "sh", "-c", full}
	case "ghostty":
		argv = []string{
			term,
			"--class=" + appID,
			"--title=" + title,
			"--window-decoration=false",
			"--initial-width=680",
			"--initial-height=420",
			"--font-size=11",
			"--background=#0c0f14",
			"--foreground=#cdd6f4",
			"--window-padding-x=15",
			"--window-padding-y=15",
			"-e", "sh", "-c", full,
		}
	case "wezterm":
		argv = []string{term, "--class", appID, "-T", title, "-e", "sh", "-c", full}
	case "xterm":
		argv = []string{term, "-class", appID, "-T", title, "-e", "sh", "-c", full}
	case "konsole":
		argv = []string{term, "--nofork", "-p", "tabtitle=" + title, "-e", "sh", "-c", full}
	case "gnome-terminal":
		argv = []string{term, "--wait", "--title=" + title, "--", "sh", "-c", full}
	default:
		argv = []string{term, "-e", "sh", "-c", full}
	}

	return argv
}

func graphicalEnviron() []string {
	env := os.Environ()
	hasDisplay := false
	hasWayland := false
	for _, e := range env {
		if strings.HasPrefix(e, "DISPLAY=") {
			hasDisplay = true
		}
		if strings.HasPrefix(e, "WAYLAND_DISPLAY=") {
			hasWayland = true
		}
	}
	if hasDisplay && hasWayland {
		return env
	}

	// Try to get them from systemd user environment
	cmd := exec.Command("systemctl", "--user", "show-environment")
	out, err := cmd.Output()
	if err == nil {
		lines := strings.Split(string(out), "\n")
		for _, line := range lines {
			line = strings.TrimSpace(line)
			if strings.HasPrefix(line, "DISPLAY=") || strings.HasPrefix(line, "WAYLAND_DISPLAY=") || strings.HasPrefix(line, "XAUTHORITY=") || strings.HasPrefix(line, "XDG_RUNTIME_DIR=") || strings.HasPrefix(line, "DBUS_SESSION_BUS_ADDRESS=") {
				env = append(env, line)
			}
		}
	}
	return env
}
