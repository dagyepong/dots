package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/acarlton5/HypeShell/core/internal/config"
	"github.com/acarlton5/HypeShell/core/internal/log"
	"github.com/spf13/cobra"
)

var customConfigPath string
var configPath string

var rootCmd = &cobra.Command{
	Use:   "hype",
	Short: "HypeShell CLI",
	Long:  "hype is the HypeShell management CLI and backend server.",
}

func init() {
	rootCmd.PersistentFlags().StringVarP(&customConfigPath, "config", "c", "", "Specify a custom path to the HypeShell config directory")
}

func findConfig(cmd *cobra.Command, args []string) error {
	if customConfigPath != "" {
		log.Debug("Custom config path provided via -c flag: %s", customConfigPath)
		shellPath := filepath.Join(customConfigPath, "shell.qml")

		info, statErr := os.Stat(shellPath)

		if statErr == nil && !info.IsDir() {
			configPath = customConfigPath
			log.Debug("Using config from: %s", configPath)
			return nil
		}

		if statErr != nil {
			return fmt.Errorf("custom config path error: %w", statErr)
		}

		return fmt.Errorf("path is a directory, not a file: %s", shellPath)
	}

	configStateFile := filepath.Join(getRuntimeDir(), "HYPESHELL.path")
	if _, err := os.Stat(configStateFile); os.IsNotExist(err) {
		configStateFile = filepath.Join(getRuntimeDir(), "hypelinux.path")
	}
	if data, readErr := os.ReadFile(configStateFile); readErr == nil {
		if len(getAllHYPEPIDs()) == 0 {
			os.Remove(configStateFile)
		} else {
			statePath := strings.TrimSpace(string(data))
			shellPath := filepath.Join(statePath, "shell.qml")

			if info, statErr := os.Stat(shellPath); statErr == nil && !info.IsDir() {
				log.Debug("Using config from active session state file: %s", statePath)
				configPath = statePath
				log.Debug("Using config from: %s", configPath)
				return nil
			}
			os.Remove(configStateFile)
		}
	}

	log.Debug("No custom path or active session, searching default XDG locations...")
	var err error
	configPath, err = config.LocateHYPEConfig()
	if err != nil {
		return err
	}

	log.Debug("Using config from: %s", configPath)
	return nil
}
