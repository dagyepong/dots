package tui

import (
	"context"
	"fmt"
	"os/exec"
	"strconv"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
)

type gccVersionCheckMsg struct {
	version string
	major   int
	err     error
}

func (m Model) viewGentooGCCCheck() string {
	var b strings.Builder

	b.WriteString(m.renderBanner())
	b.WriteString("\n")

	title := m.styles.Title.Render("GCC Version Check Failed")
	b.WriteString(title)
	b.WriteString("\n\n")

	error := m.styles.Error.Render("⚠ Hyprland requires GCC 15 or newer")
	b.WriteString(error)
	b.WriteString("\n\n")

	info := m.styles.Normal.Render("Your current GCC version is too old. Please upgrade GCC before continuing.")
	b.WriteString(info)
	b.WriteString("\n\n")

	instructionsTitle := m.styles.Subtle.Render("To upgrade GCC:")
	b.WriteString(instructionsTitle)
	b.WriteString("\n\n")

	steps := []string{
		"1. Install GCC 15 (if not already installed):",
		"   sudo emerge -1av =sys-devel/gcc:15",
		"",
		"2. Switch to GCC 15 using gcc-config:",
		"   sudo gcc-config $(gcc-config -l | grep gcc-15 | awk '{print $2}' | head -1)",
		"",
		"3. Update environment:",
		"   source /etc/profile",
		"",
		"4. Restart this installer",
	}

	for _, step := range steps {
		stepLine := m.styles.Subtle.Render(step)
		b.WriteString(stepLine)
		b.WriteString("\n")
	}

	b.WriteString("\n")
	help := m.styles.Subtle.Render("Press Esc to go back, Ctrl+C to exit")
	b.WriteString(help)

	return b.String()
}

func (m Model) updateGentooGCCCheckState(msg tea.Msg) (tea.Model, tea.Cmd) {
	if keyMsg, ok := msg.(tea.KeyMsg); ok {
		switch keyMsg.String() {
		case "esc":
			m.state = StateSelectWindowManager
			return m, nil
		}
	}
	return m, m.listenForLogs()
}

func (m Model) checkGCCVersion() tea.Cmd {
	return func() tea.Msg {
		cmd := exec.CommandContext(context.Background(), "gcc", "-dumpversion")
		output, err := cmd.Output()
		if err != nil {
			return gccVersionCheckMsg{err: err}
		}

		version := strings.TrimSpace(string(output))
		parts := strings.Split(version, ".")
		if len(parts) == 0 {
			return gccVersionCheckMsg{err: fmt.Errorf("invalid gcc version format")}
		}

		major, err := strconv.Atoi(parts[0])
		if err != nil {
			return gccVersionCheckMsg{err: err}
		}

		return gccVersionCheckMsg{
			version: version,
			major:   major,
			err:     nil,
		}
	}
}
