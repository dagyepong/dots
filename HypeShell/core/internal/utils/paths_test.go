package utils

import (
	"os"
	"path/filepath"
	"testing"
)

func TestExpandPathTilde(t *testing.T) {
	home, err := os.UserHomeDir()
	if err != nil {
		t.Skip("no home directory")
	}
	result, err := ExpandPath("~/test")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	expected := filepath.Join(home, "test")
	if result != expected {
		t.Errorf("expected %s, got %s", expected, result)
	}
}

func TestExpandPathEnvVar(t *testing.T) {
	t.Setenv("TEST_PATH_VAR", "/custom/path")
	result, err := ExpandPath("$TEST_PATH_VAR/subdir")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result != "/custom/path/subdir" {
		t.Errorf("expected /custom/path/subdir, got %s", result)
	}
}

func TestExpandPathAbsolute(t *testing.T) {
	result, err := ExpandPath("/absolute/path")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result != "/absolute/path" {
		t.Errorf("expected /absolute/path, got %s", result)
	}
}
