package themes

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/acarlton5/HypeShell/core/internal/log"
	"github.com/spf13/afero"
)

type Manager struct {
	fs        afero.Fs
	themesDir string
}

func NewManager() (*Manager, error) {
	return NewManagerWithFs(afero.NewOsFs())
}

func NewManagerWithFs(fs afero.Fs) (*Manager, error) {
	themesDir := getThemesDir()
	return &Manager{
		fs:        fs,
		themesDir: themesDir,
	}, nil
}

func getThemesDir() string {
	return filepath.Join(userConfigDir(), "HypeShell", "themes")
}

func getLegacyThemesDir() string {
	return filepath.Join(userConfigDir(), "HypeMaterialShell", "themes")
}

func userConfigDir() string {
	configDir, err := os.UserConfigDir()
	if err != nil {
		log.Error("failed to get user config dir", "err", err)
		return ""
	}
	return configDir
}

func (m *Manager) IsInstalled(theme Theme) (bool, error) {
	path := m.findInstalledPath(theme.ID)
	exists, err := afero.Exists(m.fs, path)
	if err != nil {
		return false, err
	}
	return exists, nil
}

func (m *Manager) getInstalledDir(themeID string) string {
	return filepath.Join(m.themesDir, themeID)
}

func (m *Manager) getInstalledPath(themeID string) string {
	return filepath.Join(m.getInstalledDir(themeID), "theme.json")
}

func (m *Manager) findInstalledDir(themeID string) string {
	primary := m.getInstalledDir(themeID)
	if exists, _ := afero.DirExists(m.fs, primary); exists {
		return primary
	}
	legacy := filepath.Join(getLegacyThemesDir(), themeID)
	if exists, _ := afero.DirExists(m.fs, legacy); exists {
		return legacy
	}
	return primary
}

func (m *Manager) findInstalledPath(themeID string) string {
	return filepath.Join(m.findInstalledDir(themeID), "theme.json")
}

func (m *Manager) Install(theme Theme, registryThemeDir string) error {
	themeDir := m.getInstalledDir(theme.ID)

	exists, err := afero.DirExists(m.fs, themeDir)
	if err != nil {
		return fmt.Errorf("failed to check if theme exists: %w", err)
	}

	if exists {
		return fmt.Errorf("theme already installed: %s", theme.Name)
	}

	if err := m.fs.MkdirAll(themeDir, 0o755); err != nil {
		return fmt.Errorf("failed to create theme directory: %w", err)
	}

	data, err := json.MarshalIndent(theme, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal theme: %w", err)
	}

	themePath := filepath.Join(themeDir, "theme.json")
	if err := afero.WriteFile(m.fs, themePath, data, 0o644); err != nil {
		return fmt.Errorf("failed to write theme file: %w", err)
	}

	m.copyThemeAssets(registryThemeDir, themeDir, theme)
	return nil
}

func (m *Manager) copyThemeAssets(srcDir, dstDir string, theme Theme) {
	assets := []string{"preview.svg", "preview-dark.svg", "preview-light.svg"}

	if theme.Variants != nil {
		for _, v := range theme.Variants.Options {
			assets = append(assets,
				fmt.Sprintf("preview-%s.svg", v.ID),
				fmt.Sprintf("preview-%s-dark.svg", v.ID),
				fmt.Sprintf("preview-%s-light.svg", v.ID),
			)
		}
	}

	for _, wallpaper := range theme.Wallpapers {
		assets = appendThemeAsset(assets, wallpaper.Path)
		assets = appendThemeAsset(assets, wallpaper.LightPath)
		assets = appendThemeAsset(assets, wallpaper.DarkPath)
	}

	for _, asset := range assets {
		srcPath := filepath.Join(srcDir, asset)
		if exists, _ := afero.Exists(m.fs, srcPath); !exists {
			continue
		}
		data, err := afero.ReadFile(m.fs, srcPath)
		if err != nil {
			continue
		}
		dstPath := filepath.Join(dstDir, asset)
		_ = m.fs.MkdirAll(filepath.Dir(dstPath), 0o755)
		_ = afero.WriteFile(m.fs, dstPath, data, 0o644)
	}

	m.copyThemeAssetDir(srcDir, dstDir, "wallpapers")
	m.downloadRemoteThemeAssets(dstDir, theme)
}

func appendThemeAsset(assets []string, asset string) []string {
	if asset == "" || filepath.IsAbs(asset) || strings.Contains(asset, "..") {
		return assets
	}
	return append(assets, filepath.Clean(asset))
}

func (m *Manager) copyThemeAssetDir(srcDir, dstDir, name string) {
	srcPath := filepath.Join(srcDir, name)
	if exists, _ := afero.DirExists(m.fs, srcPath); !exists {
		return
	}

	_ = afero.Walk(m.fs, srcPath, func(path string, info os.FileInfo, err error) error {
		if err != nil || info == nil || info.IsDir() {
			return nil
		}
		rel, err := filepath.Rel(srcDir, path)
		if err != nil || strings.HasPrefix(rel, "..") {
			return nil
		}
		data, err := afero.ReadFile(m.fs, path)
		if err != nil {
			return nil
		}
		dstPath := filepath.Join(dstDir, rel)
		_ = m.fs.MkdirAll(filepath.Dir(dstPath), 0o755)
		_ = afero.WriteFile(m.fs, dstPath, data, 0o644)
		return nil
	})
}

func (m *Manager) downloadRemoteThemeAssets(dstDir string, theme Theme) {
	if theme.AssetBaseURL == "" {
		return
	}

	seen := make(map[string]bool)
	for _, wallpaper := range theme.Wallpapers {
		for _, asset := range []string{wallpaper.Path, wallpaper.LightPath, wallpaper.DarkPath} {
			if asset == "" || seen[asset] {
				continue
			}
			seen[asset] = true
			if err := m.downloadRemoteThemeAsset(dstDir, theme.AssetBaseURL, asset); err != nil {
				log.Warn("failed to download theme asset", "theme", theme.ID, "asset", asset, "err", err)
			}
		}
	}
}

func (m *Manager) downloadRemoteThemeAsset(dstDir, baseURL, asset string) error {
	if filepath.IsAbs(asset) || strings.Contains(asset, "..") {
		return fmt.Errorf("unsafe asset path: %s", asset)
	}

	dstPath := filepath.Join(dstDir, filepath.Clean(asset))
	if exists, _ := afero.Exists(m.fs, dstPath); exists {
		return nil
	}

	assetURL, err := joinThemeAssetURL(baseURL, asset)
	if err != nil {
		return err
	}

	client := http.Client{Timeout: 60 * time.Second}
	resp, err := client.Get(assetURL)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("download failed: %s", resp.Status)
	}

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}

	if err := m.fs.MkdirAll(filepath.Dir(dstPath), 0o755); err != nil {
		return err
	}
	return afero.WriteFile(m.fs, dstPath, data, 0o644)
}

func joinThemeAssetURL(baseURL, asset string) (string, error) {
	baseURL = strings.TrimRight(baseURL, "/")
	if baseURL == "" {
		return "", fmt.Errorf("empty asset base URL")
	}

	parts := strings.Split(filepath.ToSlash(filepath.Clean(asset)), "/")
	return url.JoinPath(baseURL, parts...)
}

func (m *Manager) InstallFromRegistry(registry *Registry, themeID string) error {
	theme, err := registry.Get(themeID)
	if err != nil {
		return err
	}

	registryThemeDir := registry.GetThemeDir(theme.SourceDir)
	return m.Install(*theme, registryThemeDir)
}

func (m *Manager) Update(theme Theme, registryThemeDir string) error {
	themePath := m.findInstalledPath(theme.ID)

	exists, err := afero.Exists(m.fs, themePath)
	if err != nil {
		return fmt.Errorf("failed to check if theme exists: %w", err)
	}

	if !exists {
		return fmt.Errorf("theme not installed: %s", theme.Name)
	}

	data, err := json.MarshalIndent(theme, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal theme: %w", err)
	}

	if err := afero.WriteFile(m.fs, themePath, data, 0o644); err != nil {
		return fmt.Errorf("failed to write theme file: %w", err)
	}

	m.copyThemeAssets(registryThemeDir, filepath.Dir(themePath), theme)
	return nil
}

func (m *Manager) Uninstall(theme Theme) error {
	return m.UninstallByID(theme.ID)
}

func (m *Manager) UninstallByID(themeID string) error {
	themeDir := m.findInstalledDir(themeID)

	exists, err := afero.DirExists(m.fs, themeDir)
	if err != nil {
		return fmt.Errorf("failed to check if theme exists: %w", err)
	}

	if !exists {
		return fmt.Errorf("theme not installed: %s", themeID)
	}

	if err := m.fs.RemoveAll(themeDir); err != nil {
		return fmt.Errorf("failed to remove theme: %w", err)
	}

	return nil
}

func (m *Manager) ListInstalled() ([]string, error) {
	var installed []string
	seen := make(map[string]bool)
	for _, themesDir := range []string{m.themesDir, getLegacyThemesDir()} {
		exists, err := afero.DirExists(m.fs, themesDir)
		if err != nil {
			return nil, err
		}
		if !exists {
			continue
		}

		entries, err := afero.ReadDir(m.fs, themesDir)
		if err != nil {
			return nil, fmt.Errorf("failed to read themes directory: %w", err)
		}

		for _, entry := range entries {
			if !entry.IsDir() {
				continue
			}

			themeID := entry.Name()
			themePath := filepath.Join(themesDir, themeID, "theme.json")
			if exists, _ := afero.Exists(m.fs, themePath); exists && !seen[themeID] {
				seen[themeID] = true
				installed = append(installed, themeID)
			}
		}
	}

	return installed, nil
}

func (m *Manager) GetInstalledTheme(themeID string) (*Theme, error) {
	themePath := m.findInstalledPath(themeID)

	data, err := afero.ReadFile(m.fs, themePath)
	if err != nil {
		return nil, fmt.Errorf("failed to read theme file: %w", err)
	}

	var theme Theme
	if err := json.Unmarshal(data, &theme); err != nil {
		return nil, fmt.Errorf("failed to parse theme file: %w", err)
	}

	return &theme, nil
}

func (m *Manager) HasUpdates(themeID string, registryTheme Theme) (bool, error) {
	installed, err := m.GetInstalledTheme(themeID)
	if err != nil {
		return false, err
	}

	return compareVersions(installed.Version, registryTheme.Version) < 0, nil
}

func compareVersions(installed, registry string) int {
	installedParts := strings.Split(installed, ".")
	registryParts := strings.Split(registry, ".")

	maxLen := len(installedParts)
	if len(registryParts) > maxLen {
		maxLen = len(registryParts)
	}

	for i := 0; i < maxLen; i++ {
		var installedNum, registryNum int
		if i < len(installedParts) {
			fmt.Sscanf(installedParts[i], "%d", &installedNum)
		}
		if i < len(registryParts) {
			fmt.Sscanf(registryParts[i], "%d", &registryNum)
		}

		if installedNum < registryNum {
			return -1
		}
		if installedNum > registryNum {
			return 1
		}
	}

	return 0
}

func (m *Manager) GetThemesDir() string {
	return m.themesDir
}
