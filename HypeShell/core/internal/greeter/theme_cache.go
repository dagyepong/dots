package greeter

import (
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/acarlton5/HypeShell/core/internal/privesc"
)

func resolveUserThemePath(homeDir, themePath string) string {
	themePath = strings.TrimSpace(themePath)
	if themePath == "" {
		return ""
	}
	if strings.HasPrefix(themePath, "file://") {
		themePath = strings.TrimPrefix(themePath, "file://")
	}
	if strings.HasPrefix(themePath, "~/") {
		return filepath.Join(homeDir, themePath[2:])
	}
	if filepath.IsAbs(themePath) {
		return themePath
	}
	return filepath.Join(homeDir, themePath)
}

func currentThemeCachePaths() (string, string, string, bool, error) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return "", "", "", false, fmt.Errorf("failed to get user home directory: %w", err)
	}

	settings, err := readGreeterThemeSyncSettings(homeDir)
	if err != nil {
		return "", "", "", false, err
	}
	if !strings.EqualFold(settings.CurrentThemeName, "custom") || settings.CustomThemeFile == "" {
		return "", "", "", false, nil
	}

	themeFile := resolveUserThemePath(homeDir, settings.CustomThemeFile)
	if themeFile == "" {
		return "", "", "", false, nil
	}

	sourceDir := filepath.Dir(themeFile)
	themeID := filepath.Base(sourceDir)
	if themeID == "." || themeID == string(filepath.Separator) || strings.Contains(themeID, "..") {
		return "", "", "", false, fmt.Errorf("unsafe theme directory name: %s", themeID)
	}

	targetDir := filepath.Join(GreeterCacheDir, "themes", themeID)
	return sourceDir, targetDir, themeID, true, nil
}

func SyncCurrentThemeCache(logFunc func(string)) error {
	sourceDir, targetDir, themeID, ok, err := currentThemeCachePaths()
	if err != nil || !ok {
		return err
	}

	if info, err := os.Stat(filepath.Join(sourceDir, "theme.json")); err != nil {
		return fmt.Errorf("active theme file is not readable: %w", err)
	} else if info.IsDir() {
		return fmt.Errorf("active theme path points to a directory")
	}

	if err := copyDir(sourceDir, targetDir); err != nil {
		return err
	}
	if logFunc != nil {
		logFunc(fmt.Sprintf("Synced greeter theme cache: %s", themeID))
	}
	return nil
}

func SyncCurrentThemeCachePrivileged(logFunc func(string), sudoPassword string) error {
	sourceDir, targetDir, themeID, ok, err := currentThemeCachePaths()
	if err != nil || !ok {
		return err
	}

	if info, err := os.Stat(filepath.Join(sourceDir, "theme.json")); err != nil {
		return fmt.Errorf("active theme file is not readable: %w", err)
	} else if info.IsDir() {
		return fmt.Errorf("active theme path points to a directory")
	}

	if err := privesc.Run(context.Background(), sudoPassword, "mkdir", "-p", targetDir); err != nil {
		return fmt.Errorf("failed to create greeter theme cache directory: %w", err)
	}
	if err := privesc.Run(context.Background(), sudoPassword, "cp", "-a", sourceDir+string(filepath.Separator)+".", targetDir); err != nil {
		return fmt.Errorf("failed to copy active theme to greeter cache: %w", err)
	}

	owner := fmt.Sprintf("%s:%s", DetectGreeterUser(), DetectGreeterGroup())
	if err := privesc.Run(context.Background(), sudoPassword, "chown", "-R", owner, targetDir); err != nil {
		fallbackOwner := fmt.Sprintf("root:%s", DetectGreeterGroup())
		if fallbackErr := privesc.Run(context.Background(), sudoPassword, "chown", "-R", fallbackOwner, targetDir); fallbackErr != nil {
			return fmt.Errorf("failed to set greeter theme cache ownership: %w", err)
		}
	}
	if err := privesc.Run(context.Background(), sudoPassword, "chmod", "-R", "g+rX", targetDir); err != nil {
		return fmt.Errorf("failed to set greeter theme cache permissions: %w", err)
	}

	if logFunc != nil {
		logFunc(fmt.Sprintf("Synced greeter theme cache: %s", themeID))
	}
	return nil
}

func copyDir(sourceDir, targetDir string) error {
	cleanTarget := filepath.Clean(targetDir)
	cleanCache := filepath.Join(filepath.Clean(GreeterCacheDir), "themes")
	if !strings.HasPrefix(cleanTarget, cleanCache+string(filepath.Separator)) {
		return fmt.Errorf("refusing to copy theme outside greeter cache: %s", targetDir)
	}

	return filepath.WalkDir(sourceDir, func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}

		rel, err := filepath.Rel(sourceDir, path)
		if err != nil || strings.HasPrefix(rel, "..") {
			return fmt.Errorf("failed to resolve theme asset path: %s", path)
		}
		if rel == "." {
			return os.MkdirAll(targetDir, 0o775)
		}

		target := filepath.Join(targetDir, rel)
		info, err := entry.Info()
		if err != nil {
			return err
		}
		if info.Mode()&os.ModeSymlink != 0 {
			return nil
		}
		if entry.IsDir() {
			return os.MkdirAll(target, 0o775)
		}
		if !info.Mode().IsRegular() {
			return nil
		}
		return copyFile(path, target, info.Mode().Perm())
	})
}

func copyFile(source, target string, mode os.FileMode) error {
	if err := os.MkdirAll(filepath.Dir(target), 0o775); err != nil {
		return err
	}

	in, err := os.Open(source)
	if err != nil {
		return err
	}
	defer in.Close()

	out, err := os.OpenFile(target, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, mode)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		_ = out.Close()
		return err
	}
	return out.Close()
}
