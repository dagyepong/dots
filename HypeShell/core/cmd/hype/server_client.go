package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strings"

	"github.com/acarlton5/HypeShell/core/internal/server"
	"github.com/acarlton5/HypeShell/core/internal/server/models"
)

func sendServerRequest(req models.Request) (*models.Response[any], error) {
	socketPath := getServerSocketPath()

	conn, err := net.Dial("unix", socketPath)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to server (is it running?): %w", err)
	}
	defer conn.Close()

	scanner := bufio.NewScanner(conn)
	scanner.Scan() // discard initial capabilities message

	reqData, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	if _, err := conn.Write(reqData); err != nil {
		return nil, fmt.Errorf("failed to write request: %w", err)
	}

	if _, err := conn.Write([]byte("\n")); err != nil {
		return nil, fmt.Errorf("failed to write newline: %w", err)
	}

	if !scanner.Scan() {
		return nil, fmt.Errorf("failed to read response")
	}

	var resp models.Response[any]
	if err := json.Unmarshal(scanner.Bytes(), &resp); err != nil {
		return nil, fmt.Errorf("failed to unmarshal response: %w", err)
	}

	return &resp, nil
}

// sendServerRequestFireAndForget sends a request without waiting for a response.
// Useful for commands that trigger UI or async operations.
func sendServerRequestFireAndForget(req models.Request) error {
	socketPath := getServerSocketPath()

	conn, err := net.Dial("unix", socketPath)
	if err != nil {
		return fmt.Errorf("failed to connect to server (is it running?): %w", err)
	}
	defer conn.Close()

	scanner := bufio.NewScanner(conn)
	scanner.Scan() // discard initial capabilities message

	reqData, err := json.Marshal(req)
	if err != nil {
		return fmt.Errorf("failed to marshal request: %w", err)
	}

	if _, err := conn.Write(reqData); err != nil {
		return fmt.Errorf("failed to write request: %w", err)
	}

	if _, err := conn.Write([]byte("\n")); err != nil {
		return fmt.Errorf("failed to write newline: %w", err)
	}

	return nil
}

// tryServerRequest attempts to send a request but returns false if server unavailable.
// Does not log errors - caller can decide what to do on failure.
func tryServerRequest(req models.Request) (*models.Response[any], bool) {
	resp, err := sendServerRequest(req)
	if err != nil {
		return nil, false
	}
	return resp, true
}

func getServerSocketPath() string {
	runtimeDir := os.Getenv("XDG_RUNTIME_DIR")
	if runtimeDir == "" {
		runtimeDir = os.TempDir()
	}

	entries, err := os.ReadDir(runtimeDir)
	if err != nil {
		return filepath.Join(runtimeDir, "HYPESHELL.sock")
	}

	for _, entry := range entries {
		name := entry.Name()
		if name == "HYPESHELL.sock" || name == "hypelinux.sock" {
			return filepath.Join(runtimeDir, name)
		}
		if (strings.HasPrefix(name, "HYPESHELL-") || strings.HasPrefix(name, "hypelinux-")) && filepath.Ext(name) == ".sock" {
			return filepath.Join(runtimeDir, name)
		}
	}

	return server.GetSocketPath()
}
