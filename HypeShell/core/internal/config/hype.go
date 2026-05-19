package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

func LocateHYPEConfig() (string, error) {
	var primaryPaths []string
	var legacyPaths []string

	configHome, err := os.UserConfigDir()
	if err == nil && configHome != "" {
		primaryPaths = append(primaryPaths, filepath.Join(configHome, "quickshell", "hype"))
		legacyPaths = append(legacyPaths, filepath.Join(configHome, "quickshell", "hype"))
	}

	// System data directories
	dataDirs := os.Getenv("XDG_DATA_DIRS")
	if dataDirs == "" {
		dataDirs = "/usr/local/share:/usr/share"
	}

	for dir := range strings.SplitSeq(dataDirs, ":") {
		if dir != "" {
			primaryPaths = append(primaryPaths, filepath.Join(dir, "quickshell", "hype"))
			legacyPaths = append(legacyPaths, filepath.Join(dir, "quickshell", "hype"))
		}
	}

	// System config directories (fallback)
	configDirs := os.Getenv("XDG_CONFIG_DIRS")
	if configDirs == "" {
		configDirs = "/etc/xdg"
	}

	for dir := range strings.SplitSeq(configDirs, ":") {
		if dir != "" {
			primaryPaths = append(primaryPaths, filepath.Join(dir, "quickshell", "hype"))
			legacyPaths = append(legacyPaths, filepath.Join(dir, "quickshell", "hype"))
		}
	}

	// Build search paths with secondary (monorepo) paths interleaved
	var searchPaths []string
	for _, path := range append(primaryPaths, legacyPaths...) {
		searchPaths = append(searchPaths, path)
		searchPaths = append(searchPaths, filepath.Join(path, "quickshell"))
	}

	for _, path := range searchPaths {
		shellPath := filepath.Join(path, "shell.qml")
		if info, err := os.Stat(shellPath); err == nil && !info.IsDir() {
			return path, nil
		}
	}

	return "", fmt.Errorf("could not find HypeShell config (shell.qml) in any valid config path")
}
