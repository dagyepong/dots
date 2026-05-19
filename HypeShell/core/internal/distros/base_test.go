package distros

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"github.com/acarlton5/HypeShell/core/internal/deps"
	"github.com/acarlton5/HypeShell/core/internal/utils"
)

func TestBaseDistribution_detectHYPE_NotInstalled(t *testing.T) {
	originalHome := os.Getenv("HOME")
	defer os.Setenv("HOME", originalHome)

	tempDir := t.TempDir()
	os.Setenv("HOME", tempDir)

	logChan := make(chan string, 10)
	defer close(logChan)

	base := NewBaseDistribution(logChan)
	dep := base.detectHYPE()

	if dep.Status != deps.StatusMissing {
		t.Errorf("Expected StatusMissing, got %d", dep.Status)
	}

	if dep.Name != "hype (HypeMaterialShell)" {
		t.Errorf("Expected name 'hype (HypeMaterialShell)', got %s", dep.Name)
	}

	if !dep.Required {
		t.Error("Expected Required to be true")
	}
}

func TestBaseDistribution_detectHYPE_Installed(t *testing.T) {
	if !utils.CommandExists("git") {
		t.Skip("git not available")
	}

	tempDir := t.TempDir()
	hypePath := filepath.Join(tempDir, ".config", "quickshell", "hype")
	os.MkdirAll(hypePath, 0o755)

	originalHome := os.Getenv("HOME")
	defer os.Setenv("HOME", originalHome)
	os.Setenv("HOME", tempDir)

	exec.Command("git", "init", hypePath).Run()
	exec.Command("git", "-C", hypePath, "config", "user.email", "test@test.com").Run()
	exec.Command("git", "-C", hypePath, "config", "user.name", "Test User").Run()
	exec.Command("git", "-C", hypePath, "checkout", "-b", "master").Run()

	testFile := filepath.Join(hypePath, "test.txt")
	os.WriteFile(testFile, []byte("test"), 0o644)
	exec.Command("git", "-C", hypePath, "add", ".").Run()
	exec.Command("git", "-C", hypePath, "commit", "-m", "initial").Run()

	logChan := make(chan string, 10)
	defer close(logChan)

	base := NewBaseDistribution(logChan)
	dep := base.detectHYPE()

	if dep.Status == deps.StatusMissing {
		t.Error("Expected HYPE to be detected as installed")
	}

	if dep.Name != "hype (HypeMaterialShell)" {
		t.Errorf("Expected name 'hype (HypeMaterialShell)', got %s", dep.Name)
	}

	if !dep.Required {
		t.Error("Expected Required to be true")
	}

	t.Logf("Status: %d, Version: %s", dep.Status, dep.Version)
}

func TestBaseDistribution_detectHYPE_NeedsUpdate(t *testing.T) {
	if !utils.CommandExists("git") {
		t.Skip("git not available")
	}

	tempDir := t.TempDir()
	hypePath := filepath.Join(tempDir, ".config", "quickshell", "hype")
	os.MkdirAll(hypePath, 0o755)

	originalHome := os.Getenv("HOME")
	defer os.Setenv("HOME", originalHome)
	os.Setenv("HOME", tempDir)

	exec.Command("git", "init", hypePath).Run()
	exec.Command("git", "-C", hypePath, "config", "user.email", "test@test.com").Run()
	exec.Command("git", "-C", hypePath, "config", "user.name", "Test User").Run()
	exec.Command("git", "-C", hypePath, "remote", "add", "origin", "https://github.com/AvengeMedia/HypeMaterialShell.git").Run()

	testFile := filepath.Join(hypePath, "test.txt")
	os.WriteFile(testFile, []byte("test"), 0o644)
	exec.Command("git", "-C", hypePath, "add", ".").Run()
	exec.Command("git", "-C", hypePath, "commit", "-m", "initial").Run()
	exec.Command("git", "-C", hypePath, "tag", "v0.0.1").Run()
	exec.Command("git", "-C", hypePath, "checkout", "v0.0.1").Run()

	logChan := make(chan string, 10)
	defer close(logChan)

	base := NewBaseDistribution(logChan)
	dep := base.detectHYPE()

	if dep.Name != "hype (HypeMaterialShell)" {
		t.Errorf("Expected name 'hype (HypeMaterialShell)', got %s", dep.Name)
	}

	if !dep.Required {
		t.Error("Expected Required to be true")
	}

	t.Logf("Status: %d, Version: %s", dep.Status, dep.Version)
}

func TestBaseDistribution_detectHYPE_DirectoryWithoutGit(t *testing.T) {
	tempDir := t.TempDir()
	hypePath := filepath.Join(tempDir, ".config", "quickshell", "hype")
	os.MkdirAll(hypePath, 0o755)

	originalHome := os.Getenv("HOME")
	defer os.Setenv("HOME", originalHome)
	os.Setenv("HOME", tempDir)

	logChan := make(chan string, 10)
	defer close(logChan)

	base := NewBaseDistribution(logChan)
	dep := base.detectHYPE()

	if dep.Status == deps.StatusMissing {
		t.Error("Expected HYPE to be detected as present")
	}

	if dep.Name != "hype (HypeMaterialShell)" {
		t.Errorf("Expected name 'hype (HypeMaterialShell)', got %s", dep.Name)
	}

	if !dep.Required {
		t.Error("Expected Required to be true")
	}
}

func TestBaseDistribution_NewBaseDistribution(t *testing.T) {
	logChan := make(chan string, 10)
	defer close(logChan)

	base := NewBaseDistribution(logChan)

	if base == nil {
		t.Fatal("NewBaseDistribution returned nil")
	}

	if base.logChan == nil {
		t.Error("logChan was not set")
	}
}

func TestBaseDistribution_versionCompare(t *testing.T) {
	logChan := make(chan string, 10)
	defer close(logChan)

	base := NewBaseDistribution(logChan)

	tests := []struct {
		v1       string
		v2       string
		expected int
	}{
		{"0.1.0", "0.1.0", 0},
		{"0.1.0", "0.1.1", -1},
		{"0.1.1", "0.1.0", 1},
		{"0.2.0", "0.1.9", 1},
		{"1.0.0", "0.9.9", 1},
	}

	for _, tt := range tests {
		result := base.versionCompare(tt.v1, tt.v2)
		if result != tt.expected {
			t.Errorf("versionCompare(%q, %q) = %d; want %d", tt.v1, tt.v2, result, tt.expected)
		}
	}
}

func TestBaseDistribution_versionCompare_WithPrefix(t *testing.T) {
	logChan := make(chan string, 10)
	defer close(logChan)

	base := NewBaseDistribution(logChan)

	tests := []struct {
		v1       string
		v2       string
		expected int
	}{
		{"v0.1.0", "v0.1.0", 0},
		{"v0.1.0", "v0.1.1", -1},
		{"v0.1.1", "v0.1.0", 1},
	}

	for _, tt := range tests {
		result := base.versionCompare(tt.v1, tt.v2)
		if result != tt.expected {
			t.Errorf("versionCompare(%q, %q) = %d; want %d", tt.v1, tt.v2, result, tt.expected)
		}
	}
}
