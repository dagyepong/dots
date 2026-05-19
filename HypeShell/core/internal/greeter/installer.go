package greeter

import (
	"bufio"
	"context"
	_ "embed"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/acarlton5/HypeShell/core/internal/config"
	"github.com/acarlton5/HypeShell/core/internal/distros"
	"github.com/acarlton5/HypeShell/core/internal/matugen"
	sharedpam "github.com/acarlton5/HypeShell/core/internal/pam"
	"github.com/acarlton5/HypeShell/core/internal/privesc"
	"github.com/acarlton5/HypeShell/core/internal/utils"
	"github.com/sblinch/kdl-go"
	"github.com/sblinch/kdl-go/document"
)

var appArmorProfileData []byte

const appArmorProfileDest = "/etc/apparmor.d/usr.bin.hype-greeter"

const GreeterCacheDir = "/var/cache/hype-greeter"

func DetectHYPEPath() (string, error) {
	return config.LocateHYPEConfig()
}

func findGreeterWrapper(hypePath string) (string, error) {
	candidates := []string{}
	if hypePath != "" {
		candidates = append(candidates,
			filepath.Join(hypePath, "Modules", "Greetd", "assets", "hype-greeter"),
			filepath.Join(hypePath, "quickshell", "Modules", "Greetd", "assets", "hype-greeter"),
		)
	}
	candidates = append(candidates,
		"/usr/local/share/quickshell/hype/Modules/Greetd/assets/hype-greeter",
		"/usr/share/quickshell/hype/Modules/Greetd/assets/hype-greeter",
		"/etc/xdg/quickshell/hype/Modules/Greetd/assets/hype-greeter",
	)

	for _, candidate := range candidates {
		if info, err := os.Stat(candidate); err == nil && !info.IsDir() {
			return candidate, nil
		}
	}
	if hypePath == "" {
		return "", fmt.Errorf("hype-greeter wrapper not found")
	}
	return "", fmt.Errorf("hype-greeter wrapper not found near %s", hypePath)
}

// IsNixOS returns true when running on NixOS, which manages PAM configs through
// its module system. The HypeShell PAM managed block won't be written on NixOS.
func IsNixOS() bool {
	_, err := os.Stat("/etc/NIXOS")
	return err == nil
}

func DetectGreeterGroup() string {
	data, err := os.ReadFile("/etc/group")
	if err != nil {
		fmt.Fprintln(os.Stderr, "ÃƒÂ¢Ã…Â¡Ã‚Â  Warning: could not read /etc/group, defaulting to greeter")
		return "greeter"
	}

	if group, found := utils.FindGroupData(string(data), "greeter", "greetd", "_greeter"); found {
		return group
	}

	fmt.Fprintln(os.Stderr, "ÃƒÂ¢Ã…Â¡Ã‚Â  Warning: no greeter group found in /etc/group, defaulting to greeter")
	return "greeter"
}

func hasPasswdUser(passwdData, user string) bool {
	prefix := user + ":"
	for line := range strings.SplitSeq(passwdData, "\n") {
		if strings.HasPrefix(line, prefix) {
			return true
		}
	}
	return false
}

func findPasswdUser(passwdData string, candidates ...string) (string, bool) {
	for _, candidate := range candidates {
		if hasPasswdUser(passwdData, candidate) {
			return candidate, true
		}
	}
	return "", false
}

func stripTomlComment(line string) string {
	trimmed := strings.TrimSpace(line)
	if idx := strings.Index(trimmed, "#"); idx >= 0 {
		return strings.TrimSpace(trimmed[:idx])
	}
	return trimmed
}

func parseTomlSection(line string) (string, bool) {
	trimmed := stripTomlComment(line)
	if len(trimmed) < 3 || !strings.HasPrefix(trimmed, "[") || !strings.HasSuffix(trimmed, "]") {
		return "", false
	}
	return strings.TrimSpace(trimmed[1 : len(trimmed)-1]), true
}

func extractDefaultSessionUser(configContent string) string {
	inDefaultSession := false
	for line := range strings.SplitSeq(configContent, "\n") {
		if section, ok := parseTomlSection(line); ok {
			inDefaultSession = section == "default_session"
			continue
		}

		if !inDefaultSession {
			continue
		}

		trimmed := stripTomlComment(line)
		if !strings.HasPrefix(trimmed, "user =") && !strings.HasPrefix(trimmed, "user=") {
			continue
		}

		parts := strings.SplitN(trimmed, "=", 2)
		if len(parts) != 2 {
			continue
		}
		user := strings.Trim(strings.TrimSpace(parts[1]), `"`)
		if user != "" {
			return user
		}
	}

	return ""
}

func upsertDefaultSession(configContent, greeterUser, command string) string {
	lines := strings.Split(configContent, "\n")
	var out []string

	inDefaultSession := false
	foundDefaultSession := false
	defaultSessionUserSet := false
	defaultSessionCommandSet := false

	appendDefaultSessionFields := func() {
		if !defaultSessionUserSet {
			out = append(out, fmt.Sprintf(`user = "%s"`, greeterUser))
		}
		if !defaultSessionCommandSet {
			out = append(out, command)
		}
	}

	for _, line := range lines {
		if section, ok := parseTomlSection(line); ok {
			if inDefaultSession {
				appendDefaultSessionFields()
			}

			inDefaultSession = section == "default_session"
			if inDefaultSession {
				foundDefaultSession = true
				defaultSessionUserSet = false
				defaultSessionCommandSet = false
			}

			out = append(out, line)
			continue
		}

		if inDefaultSession {
			trimmed := stripTomlComment(line)
			if strings.HasPrefix(trimmed, "user =") || strings.HasPrefix(trimmed, "user=") {
				out = append(out, fmt.Sprintf(`user = "%s"`, greeterUser))
				defaultSessionUserSet = true
				continue
			}

			if strings.HasPrefix(trimmed, "command =") || strings.HasPrefix(trimmed, "command=") {
				if !defaultSessionCommandSet {
					out = append(out, command)
					defaultSessionCommandSet = true
				}
				continue
			}
		}

		out = append(out, line)
	}

	if inDefaultSession {
		appendDefaultSessionFields()
	}

	if !foundDefaultSession {
		if len(out) > 0 && strings.TrimSpace(out[len(out)-1]) != "" {
			out = append(out, "")
		}
		out = append(out, "[default_session]")
		out = append(out, fmt.Sprintf(`user = "%s"`, greeterUser))
		out = append(out, command)
	}

	return strings.Join(out, "\n")
}

func DetectGreeterUser() string {
	passwdData, err := os.ReadFile("/etc/passwd")
	if err == nil {
		passwdContent := string(passwdData)

		if configData, cfgErr := os.ReadFile("/etc/greetd/config.toml"); cfgErr == nil {
			if configured := extractDefaultSessionUser(string(configData)); configured != "" && hasPasswdUser(passwdContent, configured) {
				return configured
			}
		}

		if user, found := findPasswdUser(passwdContent, "greeter", "greetd", "_greeter"); found {
			return user
		}
	} else {
		fmt.Fprintln(os.Stderr, "ÃƒÂ¢Ã…Â¡Ã‚Â  Warning: could not read /etc/passwd, defaulting greeter user to 'greeter'")
	}

	if configData, cfgErr := os.ReadFile("/etc/greetd/config.toml"); cfgErr == nil {
		if configured := extractDefaultSessionUser(string(configData)); configured != "" {
			return configured
		}
	}

	fmt.Fprintln(os.Stderr, "ÃƒÂ¢Ã…Â¡Ã‚Â  Warning: no greeter user found, defaulting to 'greeter'")
	return "greeter"
}

func resolveGreeterWrapperPath() string {
	if override := strings.TrimSpace(os.Getenv("HYPE_GREETER_WRAPPER_CMD")); override != "" {
		return override
	}
	// Packaged installs only use the official wrapper; never fall back to /usr/local/bin.
	if IsGreeterPackaged() {
		packagedWrapper := "/usr/bin/hype-greeter"
		if info, err := os.Stat(packagedWrapper); err == nil && !info.IsDir() && (info.Mode()&0o111) != 0 {
			return packagedWrapper
		}
		fmt.Fprintln(os.Stderr, "ÃƒÂ¢Ã…Â¡Ã‚Â  Warning: packaged hype-greeter detected, but /usr/bin/hype-greeter is missing or not executable")
		return packagedWrapper
	}

	for _, candidate := range []string{"/usr/local/bin/hype-greeter", "/usr/bin/hype-greeter"} {
		if info, err := os.Stat(candidate); err == nil && !info.IsDir() && (info.Mode()&0o111) != 0 {
			return candidate
		}
	}

	if path, err := exec.LookPath("hype-greeter"); err == nil {
		resolved := path
		if realPath, realErr := filepath.EvalSymlinks(path); realErr == nil {
			resolved = realPath
		}
		if strings.HasPrefix(resolved, "/home/") || strings.HasPrefix(resolved, "/tmp/") {
			fmt.Fprintf(os.Stderr, "ÃƒÂ¢Ã…Â¡Ã‚Â  Warning: ignoring non-system hype-greeter on PATH: %s\n", path)
		} else {
			return path
		}
	}

	return "/usr/bin/hype-greeter"
}

func DetectCompositors() []string {
	var compositors []string

	if utils.CommandExists("niri") {
		compositors = append(compositors, "niri")
	}
	if utils.CommandExists("Hyprland") {
		compositors = append(compositors, "Hyprland")
	}

	return compositors
}

func PromptCompositorChoice(compositors []string) (string, error) {
	fmt.Println("\nMultiple compositors detected:")
	for i, comp := range compositors {
		fmt.Printf("%d) %s\n", i+1, comp)
	}

	reader := bufio.NewReader(os.Stdin)
	fmt.Print("Choose compositor for greeter (1-2): ")
	response, err := reader.ReadString('\n')
	if err != nil {
		return "", fmt.Errorf("error reading input: %w", err)
	}

	response = strings.TrimSpace(response)
	switch response {
	case "1":
		return compositors[0], nil
	case "2":
		if len(compositors) > 1 {
			return compositors[1], nil
		}
		return "", fmt.Errorf("invalid choice")
	default:
		return "", fmt.Errorf("invalid choice")
	}
}

// EnsureGreetdInstalled checks if greetd is installed - greetd is a daemon in /usr/sbin on Debian/Ubuntu
func EnsureGreetdInstalled(logFunc func(string), sudoPassword string) error {
	greetdFound := utils.CommandExists("greetd")
	if !greetdFound {
		for _, p := range []string{"/usr/sbin/greetd", "/sbin/greetd"} {
			if _, err := os.Stat(p); err == nil {
				greetdFound = true
				break
			}
		}
	}
	if greetdFound {
		logFunc("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ greetd is already installed")
		return nil
	}

	logFunc("greetd is not installed. Installing...")

	osInfo, err := distros.GetOSInfo()
	if err != nil {
		return fmt.Errorf("failed to detect OS: %w", err)
	}

	config, exists := distros.Registry[osInfo.Distribution.ID]
	if !exists {
		return fmt.Errorf("unsupported distribution for automatic greetd installation: %s", osInfo.Distribution.ID)
	}

	ctx := context.Background()
	var installCmd *exec.Cmd

	switch config.Family {
	case distros.FamilyArch:
		installCmd = privesc.ExecCommand(ctx, sudoPassword, "pacman -S --needed --noconfirm greetd")
	case distros.FamilyFedora:
		installCmd = privesc.ExecCommand(ctx, sudoPassword, "dnf install -y greetd")
	case distros.FamilySUSE:
		installCmd = privesc.ExecCommand(ctx, sudoPassword, "zypper install -y greetd")
	case distros.FamilyUbuntu, distros.FamilyDebian:
		installCmd = privesc.ExecCommand(ctx, sudoPassword, "apt-get install -y greetd")
	case distros.FamilyGentoo:
		installCmd = privesc.ExecCommand(ctx, sudoPassword, "emerge --ask n sys-apps/greetd")
	case distros.FamilyNix:
		return fmt.Errorf("on NixOS, please add greetd to your configuration.nix")
	default:
		return fmt.Errorf("unsupported distribution family for automatic greetd installation: %s", config.Family)
	}

	installCmd.Stdout = os.Stdout
	installCmd.Stderr = os.Stderr

	if err := installCmd.Run(); err != nil {
		return fmt.Errorf("failed to install greetd: %w", err)
	}

	logFunc("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ greetd installed successfully")
	return nil
}

// IsGreeterPackaged returns true if hype-greeter was installed from a system package.
func IsGreeterPackaged() bool {
	if !utils.CommandExists("hype-greeter") {
		return false
	}
	packagedPath := "/usr/share/quickshell/hype-greeter"
	info, err := os.Stat(packagedPath)
	return err == nil && info.IsDir()
}

// HasLegacyLocalGreeterWrapper returns true when a manually installed wrapper exists.
func HasLegacyLocalGreeterWrapper() bool {
	for _, path := range []string{"/usr/local/bin/hype-greeter", "/usr/bin/hype-greeter"} {
		info, err := os.Stat(path)
		if err == nil && !info.IsDir() {
			return true
		}
	}
	return false
}

// TryInstallGreeterPackage intentionally avoids upstream greeter packages.
func TryInstallGreeterPackage(logFunc func(string), sudoPassword string) bool {
	logFunc("Using HypeShell source greeter wrapper; no upstream greeter package will be installed")
	return false
}

// CopyGreeterFiles installs the hype-greeter wrapper and sets up cache directory
func CopyGreeterFiles(hypePath, compositor string, logFunc func(string), sudoPassword string) error {
	if IsGreeterPackaged() {
		logFunc("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ hype-greeter package already installed")
	} else {
		if hypePath == "" {
			return fmt.Errorf("HypeShell path is required for manual hype-greeter wrapper installs")
		}

		wrapperSrc, err := findGreeterWrapper(hypePath)
		if err != nil {
			return err
		}

		wrapperDst := "/usr/local/bin/hype-greeter"
		action := "Installed"
		if info, err := os.Stat(wrapperDst); err == nil && !info.IsDir() {
			action = "Updated"
		}
		if err := privesc.Run(context.Background(), sudoPassword, "cp", wrapperSrc, wrapperDst); err != nil {
			return fmt.Errorf("failed to copy hype-greeter wrapper: %w", err)
		}
		logFunc(fmt.Sprintf("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ %s hype-greeter wrapper at %s", action, wrapperDst))

		if err := privesc.Run(context.Background(), sudoPassword, "chmod", "+x", wrapperDst); err != nil {
			return fmt.Errorf("failed to make wrapper executable: %w", err)
		}

		compatWrapperDst := "/usr/bin/hype-greeter"
		if err := privesc.Run(context.Background(), sudoPassword, "cp", wrapperSrc, compatWrapperDst); err != nil {
			return fmt.Errorf("failed to copy hype-greeter system wrapper: %w", err)
		}
		if err := privesc.Run(context.Background(), sudoPassword, "chmod", "+x", compatWrapperDst); err != nil {
			return fmt.Errorf("failed to make system wrapper executable: %w", err)
		}
		logFunc(fmt.Sprintf("Installed hype-greeter wrapper at %s", compatWrapperDst))

		_ = privesc.Run(context.Background(), sudoPassword, "rm", "-f", "/usr/local/bin/dank-greeter", "/usr/bin/dank-greeter", "/usr/local/bin/dms-greeter", "/usr/bin/dms-greeter")
		osInfo, err := distros.GetOSInfo()
		if err == nil {
			if config, exists := distros.Registry[osInfo.Distribution.ID]; exists && (config.Family == distros.FamilyFedora || config.Family == distros.FamilySUSE) {
				if err := privesc.Run(context.Background(), sudoPassword, "semanage", "fcontext", "-a", "-t", "bin_t", wrapperDst); err != nil {
					logFunc(fmt.Sprintf("ÃƒÂ¢Ã…Â¡Ã‚Â  Warning: Failed to set SELinux fcontext: %v", err))
				} else {
					logFunc("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Set SELinux fcontext for hype-greeter")
				}

				if err := privesc.Run(context.Background(), sudoPassword, "restorecon", "-v", wrapperDst); err != nil {
					logFunc(fmt.Sprintf("ÃƒÂ¢Ã…Â¡Ã‚Â  Warning: Failed to restore SELinux context: %v", err))
				} else {
					logFunc("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Restored SELinux context for hype-greeter")
				}
			}
		}
	}

	if err := EnsureGreeterCacheDir(logFunc, sudoPassword); err != nil {
		return err
	}

	return nil
}

// EnsureGreeterCacheDir creates /var/cache/hype-greeter with correct ownership if it does not exist.
// It is safe to call multiple times (idempotent) and will repair ownership/mode
// when the directory already exists with stale permissions.
func EnsureGreeterCacheDir(logFunc func(string), sudoPassword string) error {
	cacheDir := GreeterCacheDir
	created := false
	if info, err := os.Stat(cacheDir); err != nil {
		if !os.IsNotExist(err) {
			return fmt.Errorf("failed to stat cache directory: %w", err)
		}
		if err := privesc.Run(context.Background(), sudoPassword, "mkdir", "-p", cacheDir); err != nil {
			return fmt.Errorf("failed to create cache directory: %w", err)
		}
		created = true
	} else if !info.IsDir() {
		return fmt.Errorf("cache path exists but is not a directory: %s", cacheDir)
	}

	group := DetectGreeterGroup()
	daemonUser := DetectGreeterUser()
	preferredOwner := fmt.Sprintf("%s:%s", daemonUser, group)
	owner := preferredOwner
	if err := privesc.Run(context.Background(), sudoPassword, "chown", owner, cacheDir); err != nil {
		// Some setups may not have a matching daemon user at this moment; fall back
		// to root:<group> while still allowing group-writable greeter runtime access.
		fallbackOwner := fmt.Sprintf("root:%s", group)
		if fallbackErr := privesc.Run(context.Background(), sudoPassword, "chown", fallbackOwner, cacheDir); fallbackErr != nil {
			return fmt.Errorf("failed to set cache directory owner (preferred %s: %v; fallback %s: %w)", preferredOwner, err, fallbackOwner, fallbackErr)
		}
		owner = fallbackOwner
	}

	if err := privesc.Run(context.Background(), sudoPassword, "chmod", "2770", cacheDir); err != nil {
		return fmt.Errorf("failed to set cache directory permissions: %w", err)
	}

	runtimeDirs := []string{
		filepath.Join(cacheDir, ".local"),
		filepath.Join(cacheDir, ".local", "state"),
		filepath.Join(cacheDir, ".local", "share"),
		filepath.Join(cacheDir, ".cache"),
	}
	for _, dir := range runtimeDirs {
		if err := privesc.Run(context.Background(), sudoPassword, "mkdir", "-p", dir); err != nil {
			return fmt.Errorf("failed to create cache runtime directory %s: %w", dir, err)
		}
		if err := privesc.Run(context.Background(), sudoPassword, "chown", owner, dir); err != nil {
			return fmt.Errorf("failed to set owner for cache runtime directory %s: %w", dir, err)
		}
		if err := privesc.Run(context.Background(), sudoPassword, "chmod", "2770", dir); err != nil {
			return fmt.Errorf("failed to set permissions for cache runtime directory %s: %w", dir, err)
		}
	}

	legacyMemoryPath := filepath.Join(cacheDir, "memory.json")
	stateMemoryPath := filepath.Join(cacheDir, ".local", "state", "memory.json")
	if err := ensureGreeterMemoryCompatLink(logFunc, sudoPassword, legacyMemoryPath, stateMemoryPath); err != nil {
		return err
	}

	if isSELinuxEnforcing() && utils.CommandExists("restorecon") {
		if err := privesc.Run(context.Background(), sudoPassword, "restorecon", "-Rv", cacheDir); err != nil {
			logFunc(fmt.Sprintf("ÃƒÂ¢Ã…Â¡Ã‚Â  Warning: Failed to restore SELinux context for %s: %v", cacheDir, err))
		}
	}

	if created {
		logFunc(fmt.Sprintf("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Created cache directory %s (owner: %s, mode: 2770)", cacheDir, owner))
	} else {
		logFunc(fmt.Sprintf("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Ensured cache directory %s permissions (owner: %s, mode: 2770)", cacheDir, owner))
	}
	return nil
}

func isSELinuxEnforcing() bool {
	data, err := os.ReadFile("/sys/fs/selinux/enforce")
	if err != nil {
		return false
	}
	return strings.TrimSpace(string(data)) == "1"
}

func ensureGreeterMemoryCompatLink(logFunc func(string), sudoPassword, legacyPath, statePath string) error {
	info, err := os.Lstat(legacyPath)
	if err == nil && info.Mode().IsRegular() {
		if _, stateErr := os.Stat(statePath); os.IsNotExist(stateErr) {
			if copyErr := privesc.Run(context.Background(), sudoPassword, "cp", "-f", legacyPath, statePath); copyErr != nil {
				logFunc(fmt.Sprintf("ÃƒÂ¢Ã…Â¡Ã‚Â  Warning: Failed to migrate legacy greeter memory file to %s: %v", statePath, copyErr))
			}
		}
	}

	if err := privesc.Run(context.Background(), sudoPassword, "ln", "-sfn", statePath, legacyPath); err != nil {
		return fmt.Errorf("failed to create greeter memory compatibility symlink %s -> %s: %w", legacyPath, statePath, err)
	}

	return nil
}

// IsAppArmorEnabled reports whether AppArmor is active on the running kernel.
func IsAppArmorEnabled() bool {
	data, err := os.ReadFile("/sys/module/apparmor/parameters/enabled")
	if err != nil {
		return false
	}
	return strings.HasPrefix(strings.TrimSpace(strings.ToLower(string(data))), "y")
}

// InstallAppArmorProfile installs the bundled AppArmor profile and reloads it. No-op on NixOS or non-AppArmor systems.
func InstallAppArmorProfile(logFunc func(string), sudoPassword string) error {
	if IsNixOS() {
		logFunc("  ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¹ Skipping AppArmor profile on NixOS (manage via security.apparmor.policies)")
		return nil
	}

	if !IsAppArmorEnabled() {
		return nil
	}

	if err := privesc.Run(context.Background(), sudoPassword, "mkdir", "-p", "/etc/apparmor.d"); err != nil {
		return fmt.Errorf("failed to create /etc/apparmor.d: %w", err)
	}

	tmp, err := os.CreateTemp("", "hype-apparmor-*")
	if err != nil {
		return fmt.Errorf("failed to create temp file for AppArmor profile: %w", err)
	}
	tmpPath := tmp.Name()
	defer os.Remove(tmpPath)

	if _, err := tmp.Write(appArmorProfileData); err != nil {
		tmp.Close()
		return fmt.Errorf("failed to write AppArmor profile: %w", err)
	}
	tmp.Close()

	if err := privesc.Run(context.Background(), sudoPassword, "cp", tmpPath, appArmorProfileDest); err != nil {
		return fmt.Errorf("failed to install AppArmor profile to %s: %w", appArmorProfileDest, err)
	}
	if err := privesc.Run(context.Background(), sudoPassword, "chmod", "644", appArmorProfileDest); err != nil {
		return fmt.Errorf("failed to set AppArmor profile permissions: %w", err)
	}

	if utils.CommandExists("apparmor_parser") {
		if err := privesc.Run(context.Background(), sudoPassword, "apparmor_parser", "-r", appArmorProfileDest); err != nil {
			logFunc(fmt.Sprintf("  ÃƒÂ¢Ã…Â¡Ã‚Â  AppArmor profile installed but reload failed: %v", err))
			logFunc("    Run: sudo apparmor_parser -r " + appArmorProfileDest)
		} else {
			logFunc("  ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ AppArmor profile installed and loaded (complain mode)")
		}
	} else {
		logFunc("  ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ AppArmor profile installed at " + appArmorProfileDest)
		logFunc("    apparmor_parser not found ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â profile will be loaded on next boot")
	}

	return nil
}

// UninstallAppArmorProfile removes the HypeShell AppArmor profile and reloads AppArmor.
// It is a no-op when AppArmor is not active or the profile does not exist.
func UninstallAppArmorProfile(logFunc func(string), sudoPassword string) error {
	if IsNixOS() {
		return nil
	}
	if _, err := os.Stat("/sys/module/apparmor"); os.IsNotExist(err) {
		return nil
	}
	if _, err := os.Stat(appArmorProfileDest); os.IsNotExist(err) {
		return nil
	}

	if utils.CommandExists("apparmor_parser") {
		_ = privesc.Run(context.Background(), sudoPassword, "apparmor_parser", "--remove", appArmorProfileDest)
	}
	if err := privesc.Run(context.Background(), sudoPassword, "rm", "-f", appArmorProfileDest); err != nil {
		return fmt.Errorf("failed to remove AppArmor profile: %w", err)
	}
	logFunc("  ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Removed HypeShell AppArmor profile")
	return nil
}

// EnsureACLInstalled installs the acl package (setfacl/getfacl) if not already present
func EnsureACLInstalled(logFunc func(string), sudoPassword string) error {
	if utils.CommandExists("setfacl") {
		return nil
	}

	logFunc("setfacl not found ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Å“ installing acl package...")

	osInfo, err := distros.GetOSInfo()
	if err != nil {
		return fmt.Errorf("failed to detect OS: %w", err)
	}

	config, exists := distros.Registry[osInfo.Distribution.ID]
	if !exists {
		return fmt.Errorf("unsupported distribution for automatic acl installation: %s", osInfo.Distribution.ID)
	}

	ctx := context.Background()
	var installCmd *exec.Cmd

	switch config.Family {
	case distros.FamilyArch:
		installCmd = privesc.ExecCommand(ctx, sudoPassword, "pacman -S --needed --noconfirm acl")
	case distros.FamilyFedora:
		installCmd = privesc.ExecCommand(ctx, sudoPassword, "dnf install -y acl")
	case distros.FamilySUSE:
		installCmd = privesc.ExecCommand(ctx, sudoPassword, "zypper install -y acl")
	case distros.FamilyUbuntu, distros.FamilyDebian:
		installCmd = privesc.ExecCommand(ctx, sudoPassword, "apt-get install -y acl")
	case distros.FamilyGentoo:
		installCmd = privesc.ExecCommand(ctx, sudoPassword, "emerge --ask n sys-fs/acl")
	case distros.FamilyNix:
		return fmt.Errorf("on NixOS, please add pkgs.acl to your configuration.nix")
	default:
		return fmt.Errorf("unsupported distribution family for automatic acl installation: %s", config.Family)
	}

	installCmd.Stdout = os.Stdout
	installCmd.Stderr = os.Stderr
	if err := installCmd.Run(); err != nil {
		return fmt.Errorf("failed to install acl: %w", err)
	}

	logFunc("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ acl package installed")
	return nil
}

// SetupParentDirectoryACLs sets ACLs on parent directories to allow traversal
func SetupParentDirectoryACLs(logFunc func(string), sudoPassword string) error {
	if err := EnsureACLInstalled(logFunc, sudoPassword); err != nil {
		logFunc(fmt.Sprintf("ÃƒÂ¢Ã…Â¡Ã‚Â  Warning: could not install acl package: %v", err))
		logFunc("  ACL permissions will be skipped; theme sync may not work correctly.")
		return nil
	}
	if !utils.CommandExists("setfacl") {
		logFunc("ÃƒÂ¢Ã…Â¡Ã‚Â  Warning: setfacl still not available after install attempt; skipping ACL setup.")
		return nil
	}

	homeDir, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("failed to get user home directory: %w", err)
	}

	parentDirs := []struct {
		path string
		desc string
	}{
		{homeDir, "home directory"},
		{filepath.Join(homeDir, ".config"), ".config directory"},
		{filepath.Join(homeDir, ".local"), ".local directory"},
		{filepath.Join(homeDir, ".cache"), ".cache directory"},
		{filepath.Join(homeDir, ".local", "state"), ".local/state directory"},
		{filepath.Join(homeDir, ".local", "share"), ".local/share directory"},
	}

	group := DetectGreeterGroup()

	logFunc("\nSetting up parent directory ACLs for greeter user access...")

	for _, dir := range parentDirs {
		if _, err := os.Stat(dir.path); os.IsNotExist(err) {
			if err := os.MkdirAll(dir.path, 0o755); err != nil {
				logFunc(fmt.Sprintf("ÃƒÂ¢Ã…Â¡Ã‚Â  Warning: Could not create %s: %v", dir.desc, err))
				continue
			}
		}

		// Group ACL covers daemon users regardless of username (e.g. greetd ÃƒÂ¢Ã¢â‚¬Â°Ã‚Â  greeter on Fedora).
		if err := privesc.Run(context.Background(), sudoPassword, "setfacl", "-m", fmt.Sprintf("g:%s:rX", group), dir.path); err != nil {
			logFunc(fmt.Sprintf("ÃƒÂ¢Ã…Â¡Ã‚Â  Warning: Failed to set ACL on %s: %v", dir.desc, err))
			logFunc(fmt.Sprintf("  You may need to run manually: setfacl -m g:%s:rX %s", group, dir.path))
			continue
		}

		logFunc(fmt.Sprintf("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Set ACL on %s", dir.desc))
	}

	return nil
}

// RemediateStaleACLs removes user-based ACLs left by older binary versions. Best-effort.
func RemediateStaleACLs(logFunc func(string), sudoPassword string) {
	if !utils.CommandExists("setfacl") {
		return
	}

	homeDir, err := os.UserHomeDir()
	if err != nil {
		return
	}

	passwdData, err := os.ReadFile("/etc/passwd")
	if err != nil {
		return
	}

	dirs := []string{
		homeDir,
		filepath.Join(homeDir, ".config"),
		filepath.Join(homeDir, ".config", "HypeShell"),
		filepath.Join(homeDir, ".cache"),
		filepath.Join(homeDir, ".cache", "HypeShell"),
		filepath.Join(homeDir, ".local"),
		filepath.Join(homeDir, ".local", "state"),
		filepath.Join(homeDir, ".local", "share"),
	}

	passwdContent := string(passwdData)
	staleUsers := []string{"greeter", "greetd", "_greeter"}
	existingUsers := make([]string, 0, len(staleUsers))
	for _, user := range staleUsers {
		if hasPasswdUser(passwdContent, user) {
			existingUsers = append(existingUsers, user)
		}
	}
	if len(existingUsers) == 0 {
		return
	}

	cleaned := false
	for _, dir := range dirs {
		if _, err := os.Stat(dir); err != nil {
			continue
		}
		for _, user := range existingUsers {
			_ = privesc.Run(context.Background(), sudoPassword, "setfacl", "-x", fmt.Sprintf("u:%s", user), dir)
			cleaned = true
		}
	}
	if cleaned {
		logFunc("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Cleaned up stale user-based ACLs from previous versions")
	}
}

// RemediateStaleAppArmor removes any AppArmor profile installed by an older binary on
// systems where AppArmor is not active.
func RemediateStaleAppArmor(logFunc func(string), sudoPassword string) {
	if IsAppArmorEnabled() {
		return
	}
	if _, err := os.Stat(appArmorProfileDest); os.IsNotExist(err) {
		return
	}
	logFunc("ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¹ Removing stale AppArmor profile (AppArmor is not active on this system)")
	_ = UninstallAppArmorProfile(logFunc, sudoPassword)
}

func SetupHYPEGroup(logFunc func(string), sudoPassword string) error {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("failed to get user home directory: %w", err)
	}

	currentUser := os.Getenv("USER")
	if currentUser == "" {
		currentUser = os.Getenv("LOGNAME")
	}
	if currentUser == "" {
		return fmt.Errorf("failed to determine current user")
	}

	group := DetectGreeterGroup()

	// Create the group if it doesn't exist yet (e.g. before greetd package is installed).
	if !utils.HasGroup(group) {
		if err := privesc.Run(context.Background(), sudoPassword, "groupadd", "-r", group); err != nil {
			return fmt.Errorf("failed to create %s group: %w", group, err)
		}
		logFunc(fmt.Sprintf("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Created system group %s", group))
	}

	groupsCmd := exec.Command("groups", currentUser)
	groupsOutput, err := groupsCmd.Output()
	if err == nil && strings.Contains(string(groupsOutput), group) {
		logFunc(fmt.Sprintf("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ %s is already in %s group", currentUser, group))
	} else {
		if err := privesc.Run(context.Background(), sudoPassword, "usermod", "-aG", group, currentUser); err != nil {
			return fmt.Errorf("failed to add %s to %s group: %w", currentUser, group, err)
		}
		logFunc(fmt.Sprintf("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Added %s to %s group (logout/login required for changes to take effect)", currentUser, group))
	}

	// Also add the daemon user (e.g. greetd on Fedora) so group ACLs apply to the running process.
	daemonUser := DetectGreeterUser()
	if daemonUser != currentUser {
		daemonGroupsCmd := exec.Command("groups", daemonUser)
		daemonGroupsOutput, daemonGroupsErr := daemonGroupsCmd.Output()
		if daemonGroupsErr == nil {
			if strings.Contains(string(daemonGroupsOutput), group) {
				logFunc(fmt.Sprintf("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Greeter daemon user %s is already in %s group", daemonUser, group))
			} else {
				if err := privesc.Run(context.Background(), sudoPassword, "usermod", "-aG", group, daemonUser); err != nil {
					logFunc(fmt.Sprintf("ÃƒÂ¢Ã…Â¡Ã‚Â  Warning: could not add %s to %s group: %v", daemonUser, group, err))
				} else {
					logFunc(fmt.Sprintf("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Added greeter daemon user %s to %s group", daemonUser, group))
				}
			}
		}
	}

	configDirs := []struct {
		path string
		desc string
	}{
		{filepath.Join(homeDir, ".config", "HypeShell"), "HypeShell config"},
		{filepath.Join(homeDir, ".local", "state", "HypeShell"), "HypeShell state"},
		{filepath.Join(homeDir, ".cache", "HypeShell"), "HypeShell cache"},
		{filepath.Join(homeDir, ".cache", "quickshell"), "quickshell cache"},
		{filepath.Join(homeDir, ".config", "quickshell"), "quickshell config"},
		{filepath.Join(homeDir, ".local", "share", "wayland-sessions"), "wayland sessions"},
		{filepath.Join(homeDir, ".local", "share", "xsessions"), "xsessions"},
	}

	for _, dir := range configDirs {
		if _, err := os.Stat(dir.path); os.IsNotExist(err) {
			if err := os.MkdirAll(dir.path, 0o755); err != nil {
				logFunc(fmt.Sprintf("ÃƒÂ¢Ã…Â¡Ã‚Â  Warning: Could not create %s: %v", dir.path, err))
				continue
			}
		}

		if err := privesc.Run(context.Background(), sudoPassword, "chgrp", "-R", group, dir.path); err != nil {
			logFunc(fmt.Sprintf("ÃƒÂ¢Ã…Â¡Ã‚Â  Warning: Failed to set group for %s: %v", dir.desc, err))
			continue
		}

		if err := privesc.Run(context.Background(), sudoPassword, "chmod", "-R", "g+rX", dir.path); err != nil {
			logFunc(fmt.Sprintf("ÃƒÂ¢Ã…Â¡Ã‚Â  Warning: Failed to set permissions for %s: %v", dir.desc, err))
			continue
		}

		logFunc(fmt.Sprintf("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Set group permissions for %s", dir.desc))
	}

	if err := SetupParentDirectoryACLs(logFunc, sudoPassword); err != nil {
		return fmt.Errorf("failed to setup parent directory ACLs: %w", err)
	}

	return nil
}

type GreeterColorSyncInfo struct {
	SourcePath                   string
	ThemeName                    string
	UsesDynamicWallpaperOverride bool
}

type greeterThemeSyncSettings struct {
	CurrentThemeName     string `json:"currentThemeName"`
	CustomThemeFile      string `json:"customThemeFile"`
	GreeterWallpaperPath string `json:"greeterWallpaperPath"`
	MatugenScheme        string `json:"matugenScheme"`
	IconTheme            string `json:"iconTheme"`
}

type greeterThemeSyncSession struct {
	IsLightMode bool `json:"isLightMode"`
}

type greeterThemeSyncState struct {
	ThemeName                    string
	GreeterWallpaperPath         string
	ResolvedGreeterWallpaperPath string
	MatugenScheme                string
	IconTheme                    string
	IsLightMode                  bool
	UsesDynamicWallpaperOverride bool
}

func defaultGreeterColorsSource(homeDir string) string {
	return filepath.Join(homeDir, ".cache", "HypeShell", "hype-colors.json")
}

func greeterOverrideColorsStateDir(homeDir string) string {
	return filepath.Join(homeDir, ".cache", "HypeShell", "greeter-colors")
}

func greeterOverrideColorsSource(homeDir string) string {
	return filepath.Join(greeterOverrideColorsStateDir(homeDir), "hype-colors.json")
}

func readOptionalJSONFile(path string, dst any) error {
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	if strings.TrimSpace(string(data)) == "" {
		return nil
	}
	return json.Unmarshal(data, dst)
}

func readGreeterThemeSyncSettings(homeDir string) (greeterThemeSyncSettings, error) {
	settings := greeterThemeSyncSettings{
		CurrentThemeName: "purple",
		MatugenScheme:    "scheme-tonal-spot",
		IconTheme:        "System Default",
	}
	settingsPath := filepath.Join(homeDir, ".config", "HypeShell", "settings.json")
	if err := readOptionalJSONFile(settingsPath, &settings); err != nil {
		return greeterThemeSyncSettings{}, fmt.Errorf("failed to parse settings at %s: %w", settingsPath, err)
	}
	return settings, nil
}

func readGreeterThemeSyncSession(homeDir string) (greeterThemeSyncSession, error) {
	session := greeterThemeSyncSession{}
	sessionPath := filepath.Join(homeDir, ".local", "state", "HypeShell", "session.json")
	if err := readOptionalJSONFile(sessionPath, &session); err != nil {
		return greeterThemeSyncSession{}, fmt.Errorf("failed to parse session at %s: %w", sessionPath, err)
	}
	return session, nil
}

func resolveGreeterThemeSyncState(homeDir string) (greeterThemeSyncState, error) {
	settings, err := readGreeterThemeSyncSettings(homeDir)
	if err != nil {
		return greeterThemeSyncState{}, err
	}
	session, err := readGreeterThemeSyncSession(homeDir)
	if err != nil {
		return greeterThemeSyncState{}, err
	}

	resolvedWallpaperPath := ""
	if settings.GreeterWallpaperPath != "" {
		resolvedWallpaperPath = settings.GreeterWallpaperPath
		if !filepath.IsAbs(resolvedWallpaperPath) {
			resolvedWallpaperPath = filepath.Join(homeDir, resolvedWallpaperPath)
		}
	}

	usesDynamicWallpaperOverride := strings.EqualFold(strings.TrimSpace(settings.CurrentThemeName), "dynamic") && resolvedWallpaperPath != ""

	return greeterThemeSyncState{
		ThemeName:                    settings.CurrentThemeName,
		GreeterWallpaperPath:         settings.GreeterWallpaperPath,
		ResolvedGreeterWallpaperPath: resolvedWallpaperPath,
		MatugenScheme:                settings.MatugenScheme,
		IconTheme:                    settings.IconTheme,
		IsLightMode:                  session.IsLightMode,
		UsesDynamicWallpaperOverride: usesDynamicWallpaperOverride,
	}, nil
}

func (s greeterThemeSyncState) effectiveColorsSource(homeDir string) string {
	if s.UsesDynamicWallpaperOverride {
		return greeterOverrideColorsSource(homeDir)
	}
	return defaultGreeterColorsSource(homeDir)
}

func ResolveGreeterColorSyncInfo(homeDir string) (GreeterColorSyncInfo, error) {
	state, err := resolveGreeterThemeSyncState(homeDir)
	if err != nil {
		return GreeterColorSyncInfo{}, err
	}
	return GreeterColorSyncInfo{
		SourcePath:                   state.effectiveColorsSource(homeDir),
		ThemeName:                    state.ThemeName,
		UsesDynamicWallpaperOverride: state.UsesDynamicWallpaperOverride,
	}, nil
}

func ensureGreeterSyncSourceFile(path string) error {
	sourceDir := filepath.Dir(path)
	if err := os.MkdirAll(sourceDir, 0o755); err != nil {
		return fmt.Errorf("failed to create source directory %s: %w", sourceDir, err)
	}

	if _, err := os.Stat(path); os.IsNotExist(err) {
		if err := os.WriteFile(path, []byte("{}"), 0o644); err != nil {
			return fmt.Errorf("failed to create source file %s: %w", path, err)
		}
	} else if err != nil {
		return fmt.Errorf("failed to inspect source file %s: %w", path, err)
	}

	return nil
}

func syncGreeterDynamicOverrideColors(hypePath, homeDir string, state greeterThemeSyncState, logFunc func(string)) error {
	if !state.UsesDynamicWallpaperOverride {
		return nil
	}

	st, err := os.Stat(state.ResolvedGreeterWallpaperPath)
	if err != nil {
		return fmt.Errorf("configured greeter wallpaper not found at %s: %w", state.ResolvedGreeterWallpaperPath, err)
	}
	if st.IsDir() {
		return fmt.Errorf("configured greeter wallpaper path points to a directory: %s", state.ResolvedGreeterWallpaperPath)
	}

	mode := matugen.ColorModeDark
	if state.IsLightMode {
		mode = matugen.ColorModeLight
	}

	opts := matugen.Options{
		StateDir:         greeterOverrideColorsStateDir(homeDir),
		ShellDir:         hypePath,
		ConfigDir:        filepath.Join(homeDir, ".config"),
		Kind:             "image",
		Value:            state.ResolvedGreeterWallpaperPath,
		Mode:             mode,
		IconTheme:        state.IconTheme,
		MatugenType:      state.MatugenScheme,
		RunUserTemplates: false,
		ColorsOnly:       true,
	}

	err = matugen.Run(opts)
	switch {
	case errors.Is(err, matugen.ErrNoChanges):
		logFunc("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Greeter dynamic override colors already up to date")
		return nil
	case err != nil:
		return fmt.Errorf("failed to generate greeter dynamic colors from wallpaper override: %w", err)
	default:
		logFunc("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Generated greeter dynamic colors from wallpaper override")
		return nil
	}
}

func syncGreeterColorSource(homeDir, cacheDir string, state greeterThemeSyncState, logFunc func(string), sudoPassword string) error {
	source := state.effectiveColorsSource(homeDir)
	if !state.UsesDynamicWallpaperOverride {
		if err := ensureGreeterSyncSourceFile(source); err != nil {
			return err
		}
	} else if _, err := os.Stat(source); err != nil {
		return fmt.Errorf("expected generated greeter colors at %s: %w", source, err)
	}

	target := filepath.Join(cacheDir, "colors.json")
	_ = privesc.Run(context.Background(), sudoPassword, "rm", "-f", target)
	if err := privesc.Run(context.Background(), sudoPassword, "ln", "-sf", source, target); err != nil {
		return fmt.Errorf("failed to create symlink for wallpaper based theming (%s -> %s): %w", target, source, err)
	}

	if state.UsesDynamicWallpaperOverride {
		logFunc("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Synced wallpaper based theming (greeter wallpaper override)")
	} else {
		logFunc("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Synced wallpaper based theming")
	}

	return nil
}

func SyncHYPEConfigs(hypePath, compositor string, logFunc func(string), sudoPassword string) error {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("failed to get user home directory: %w", err)
	}

	cacheDir := GreeterCacheDir

	symlinks := []struct {
		source string
		target string
		desc   string
	}{
		{
			source: filepath.Join(homeDir, ".config", "HypeShell", "settings.json"),
			target: filepath.Join(cacheDir, "settings.json"),
			desc:   "core settings (theme, clock formats, etc)",
		},
		{
			source: filepath.Join(homeDir, ".local", "state", "HypeShell", "session.json"),
			target: filepath.Join(cacheDir, "session.json"),
			desc:   "state (wallpaper configuration)",
		},
	}

	for _, link := range symlinks {
		sourceDir := filepath.Dir(link.source)
		if _, err := os.Stat(sourceDir); os.IsNotExist(err) {
			if err := os.MkdirAll(sourceDir, 0o755); err != nil {
				return fmt.Errorf("failed to create source directory %s for %s: %w", sourceDir, link.desc, err)
			}
		}

		if _, err := os.Stat(link.source); os.IsNotExist(err) {
			if err := os.WriteFile(link.source, []byte("{}"), 0o644); err != nil {
				return fmt.Errorf("failed to create source file %s for %s: %w", link.source, link.desc, err)
			}
		}

		_ = privesc.Run(context.Background(), sudoPassword, "rm", "-f", link.target)

		if err := privesc.Run(context.Background(), sudoPassword, "ln", "-sf", link.source, link.target); err != nil {
			return fmt.Errorf("failed to create symlink for %s (%s -> %s): %w", link.desc, link.target, link.source, err)
		}

		logFunc(fmt.Sprintf("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Synced %s", link.desc))
	}

	state, err := resolveGreeterThemeSyncState(homeDir)
	if err != nil {
		return fmt.Errorf("failed to resolve greeter color source: %w", err)
	}

	if err := syncGreeterDynamicOverrideColors(hypePath, homeDir, state, logFunc); err != nil {
		return err
	}

	if err := syncGreeterColorSource(homeDir, cacheDir, state, logFunc, sudoPassword); err != nil {
		return err
	}

	if err := SyncCurrentThemeCachePrivileged(logFunc, sudoPassword); err != nil {
		logFunc(fmt.Sprintf("Warning: Failed to sync active theme to greeter cache: %v", err))
	}

	if err := syncGreeterWallpaperOverride(cacheDir, logFunc, sudoPassword, state); err != nil {
		return fmt.Errorf("greeter wallpaper override sync failed: %w", err)
	}

	if strings.ToLower(compositor) != "niri" {
		return nil
	}

	if err := syncNiriGreeterConfig(logFunc, sudoPassword); err != nil {
		logFunc(fmt.Sprintf("ÃƒÂ¢Ã…Â¡Ã‚Â  Warning: Failed to sync niri greeter config: %v", err))
	}

	return nil
}

func syncGreeterWallpaperOverride(cacheDir string, logFunc func(string), sudoPassword string, state greeterThemeSyncState) error {
	destPath := filepath.Join(cacheDir, "greeter_wallpaper_override.jpg")
	if state.ResolvedGreeterWallpaperPath == "" {
		if err := privesc.Run(context.Background(), sudoPassword, "rm", "-f", destPath); err != nil {
			return fmt.Errorf("failed to clear override file %s: %w", destPath, err)
		}
		logFunc("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Cleared greeter wallpaper override")
		return nil
	}
	if err := privesc.Run(context.Background(), sudoPassword, "rm", "-f", destPath); err != nil {
		return fmt.Errorf("failed to remove old override file %s: %w", destPath, err)
	}
	src := state.ResolvedGreeterWallpaperPath
	st, err := os.Stat(src)
	if err != nil {
		return fmt.Errorf("configured greeter wallpaper not found at %s: %w", src, err)
	}
	if st.IsDir() {
		return fmt.Errorf("configured greeter wallpaper path points to a directory: %s", src)
	}
	if err := privesc.Run(context.Background(), sudoPassword, "cp", src, destPath); err != nil {
		return fmt.Errorf("failed to copy override wallpaper to %s: %w", destPath, err)
	}
	greeterGroup := DetectGreeterGroup()
	daemonUser := DetectGreeterUser()
	if err := privesc.Run(context.Background(), sudoPassword, "chown", daemonUser+":"+greeterGroup, destPath); err != nil {
		if fallbackErr := privesc.Run(context.Background(), sudoPassword, "chown", "root:"+greeterGroup, destPath); fallbackErr != nil {
			return fmt.Errorf("failed to set override ownership on %s: %w", destPath, err)
		}
	}
	if err := privesc.Run(context.Background(), sudoPassword, "chmod", "644", destPath); err != nil {
		return fmt.Errorf("failed to set override permissions on %s: %w", destPath, err)
	}
	logFunc("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Synced greeter wallpaper override")
	return nil
}

type niriGreeterSync struct {
	processed   map[string]bool
	nodes       []*document.Node
	inputCount  int
	outputCount int
	cursorCount int
	debugCount  int
	cursorNode  *document.Node
	inputNode   *document.Node
	outputNodes map[string]*document.Node
}

func syncNiriGreeterConfig(logFunc func(string), sudoPassword string) error {
	configDir, err := os.UserConfigDir()
	if err != nil {
		return fmt.Errorf("failed to resolve user config directory: %w", err)
	}

	configPath := filepath.Join(configDir, "niri", "config.kdl")
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		logFunc("ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¹ Niri config not found; skipping greeter niri sync")
		return nil
	} else if err != nil {
		return fmt.Errorf("failed to stat niri config: %w", err)
	}

	extractor := &niriGreeterSync{
		processed:   make(map[string]bool),
		outputNodes: make(map[string]*document.Node),
	}

	if err := extractor.processFile(configPath); err != nil {
		return err
	}

	if len(extractor.nodes) == 0 {
		logFunc("ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¹ No niri input/output sections found; skipping greeter niri sync")
		return nil
	}

	content := extractor.render()
	if strings.TrimSpace(content) == "" {
		logFunc("ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¹ No niri input/output content to sync; skipping greeter niri sync")
		return nil
	}

	greeterDir := "/etc/greetd/niri"
	greeterGroup := DetectGreeterGroup()
	if err := privesc.Run(context.Background(), sudoPassword, "mkdir", "-p", greeterDir); err != nil {
		return fmt.Errorf("failed to create greetd niri directory: %w", err)
	}
	if err := privesc.Run(context.Background(), sudoPassword, "chown", fmt.Sprintf("root:%s", greeterGroup), greeterDir); err != nil {
		return fmt.Errorf("failed to set greetd niri directory ownership: %w", err)
	}
	if err := privesc.Run(context.Background(), sudoPassword, "chmod", "755", greeterDir); err != nil {
		return fmt.Errorf("failed to set greetd niri directory permissions: %w", err)
	}

	hypeTemp, err := os.CreateTemp("", "hype-greeter-niri-hype-*.kdl")
	if err != nil {
		return fmt.Errorf("failed to create temp file: %w", err)
	}
	defer os.Remove(hypeTemp.Name())

	if _, err := hypeTemp.WriteString(content); err != nil {
		_ = hypeTemp.Close()
		return fmt.Errorf("failed to write temp niri config: %w", err)
	}
	if err := hypeTemp.Close(); err != nil {
		return fmt.Errorf("failed to close temp niri config: %w", err)
	}

	hypePath := filepath.Join(greeterDir, "hype.kdl")
	if err := backupFileIfExists(sudoPassword, hypePath, ".backup"); err != nil {
		return fmt.Errorf("failed to backup %s: %w", hypePath, err)
	}
	if err := privesc.Run(context.Background(), sudoPassword, "install", "-o", "root", "-g", greeterGroup, "-m", "0644", hypeTemp.Name(), hypePath); err != nil {
		return fmt.Errorf("failed to install greetd niri hype config: %w", err)
	}

	mainContent := fmt.Sprintf("%s\ninclude \"%s\"\n", config.NiriGreeterConfig, hypePath)
	mainTemp, err := os.CreateTemp("", "hype-greeter-niri-main-*.kdl")
	if err != nil {
		return fmt.Errorf("failed to create temp file: %w", err)
	}
	defer os.Remove(mainTemp.Name())

	if _, err := mainTemp.WriteString(mainContent); err != nil {
		_ = mainTemp.Close()
		return fmt.Errorf("failed to write temp niri main config: %w", err)
	}
	if err := mainTemp.Close(); err != nil {
		return fmt.Errorf("failed to close temp niri main config: %w", err)
	}

	mainPath := filepath.Join(greeterDir, "config.kdl")
	if err := backupFileIfExists(sudoPassword, mainPath, ".backup"); err != nil {
		return fmt.Errorf("failed to backup %s: %w", mainPath, err)
	}
	if err := privesc.Run(context.Background(), sudoPassword, "install", "-o", "root", "-g", greeterGroup, "-m", "0644", mainTemp.Name(), mainPath); err != nil {
		return fmt.Errorf("failed to install greetd niri main config: %w", err)
	}

	if err := ensureGreetdNiriConfig(logFunc, sudoPassword, mainPath); err != nil {
		logFunc(fmt.Sprintf("ÃƒÂ¢Ã…Â¡Ã‚Â  Warning: Failed to update greetd config for niri: %v", err))
	}

	logFunc(fmt.Sprintf("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Synced niri greeter config (%d input, %d output, %d cursor, %d debug) to %s", extractor.inputCount, extractor.outputCount, extractor.cursorCount, extractor.debugCount, hypePath))
	return nil
}

func ensureGreetdNiriConfig(logFunc func(string), sudoPassword string, niriConfigPath string) error {
	configPath := "/etc/greetd/config.toml"
	data, err := os.ReadFile(configPath)
	if os.IsNotExist(err) {
		logFunc("ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¹ greetd config not found; skipping niri config wiring")
		return nil
	}
	if err != nil {
		return fmt.Errorf("failed to read greetd config: %w", err)
	}

	lines := strings.Split(string(data), "\n")
	updated := false
	for i, line := range lines {
		trimmed := strings.TrimSpace(line)
		if !strings.HasPrefix(trimmed, "command") {
			continue
		}

		parts := strings.SplitN(trimmed, "=", 2)
		if len(parts) != 2 {
			continue
		}

		command := strings.Trim(strings.TrimSpace(parts[1]), "\"")
		if !strings.Contains(command, "hype-greeter") {
			continue
		}
		if !strings.Contains(command, "--command niri") {
			continue
		}
		command = stripConfigFlag(command)
		command = stripCacheDirFlag(command)
		command = strings.TrimSpace(command + " --cache-dir " + GreeterCacheDir)

		newCommand := fmt.Sprintf("%s -C %s", command, niriConfigPath)
		idx := strings.Index(line, "command")
		leading := ""
		if idx > 0 {
			leading = line[:idx]
		}
		lines[i] = fmt.Sprintf("%scommand = \"%s\"", leading, newCommand)
		updated = true
		break
	}

	if !updated {
		return nil
	}

	tmpFile, err := os.CreateTemp("", "greetd-config-*.toml")
	if err != nil {
		return fmt.Errorf("failed to create temp greetd config: %w", err)
	}
	defer os.Remove(tmpFile.Name())

	if _, err := tmpFile.WriteString(strings.Join(lines, "\n")); err != nil {
		_ = tmpFile.Close()
		return fmt.Errorf("failed to write temp greetd config: %w", err)
	}
	if err := tmpFile.Close(); err != nil {
		return fmt.Errorf("failed to close temp greetd config: %w", err)
	}

	if err := privesc.Run(context.Background(), sudoPassword, "mv", tmpFile.Name(), configPath); err != nil {
		return fmt.Errorf("failed to update greetd config: %w", err)
	}

	logFunc(fmt.Sprintf("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Updated greetd config to use niri config %s", niriConfigPath))
	return nil
}

func backupFileIfExists(sudoPassword string, path string, suffix string) error {
	if _, err := os.Stat(path); os.IsNotExist(err) {
		return nil
	} else if err != nil {
		return err
	}

	backupPath := fmt.Sprintf("%s%s-%s", path, suffix, time.Now().Format("20060102-150405"))
	if err := privesc.Run(context.Background(), sudoPassword, "cp", path, backupPath); err != nil {
		return err
	}
	return privesc.Run(context.Background(), sudoPassword, "chmod", "644", backupPath)
}

func (s *niriGreeterSync) processFile(filePath string) error {
	absPath, err := filepath.Abs(filePath)
	if err != nil {
		return fmt.Errorf("failed to resolve path %s: %w", filePath, err)
	}

	if s.processed[absPath] {
		return nil
	}
	s.processed[absPath] = true

	data, err := os.ReadFile(absPath)
	if err != nil {
		return fmt.Errorf("failed to read %s: %w", absPath, err)
	}

	doc, err := kdl.Parse(strings.NewReader(string(data)))
	if err != nil {
		return fmt.Errorf("failed to parse KDL in %s: %w", absPath, err)
	}

	baseDir := filepath.Dir(absPath)
	for _, node := range doc.Nodes {
		name := node.Name.String()
		switch name {
		case "include":
			if err := s.handleInclude(node, baseDir); err != nil {
				return err
			}
		case "input":
			if s.inputNode == nil {
				s.inputNode = node
				s.inputNode.Children = dedupeCursorChildren(s.inputNode.Children)
				s.nodes = append(s.nodes, node)
			} else if len(node.Children) > 0 {
				s.inputNode.Children = mergeInputChildren(s.inputNode.Children, node.Children)
			}
			s.inputCount++
		case "output":
			key := outputNodeKey(node)
			if existing, ok := s.outputNodes[key]; ok {
				*existing = *node
			} else {
				s.outputNodes[key] = node
				s.nodes = append(s.nodes, node)
			}
			s.outputCount++
		case "cursor":
			if s.cursorNode == nil {
				s.cursorNode = node
				s.cursorNode.Children = dedupeCursorChildren(s.cursorNode.Children)
				s.nodes = append(s.nodes, node)
				s.cursorCount++
			} else if len(node.Children) > 0 {
				s.cursorNode.Children = mergeCursorChildren(s.cursorNode.Children, node.Children)
			}
		case "debug":
			s.nodes = append(s.nodes, node)
			s.debugCount++
		}
	}

	return nil
}

func mergeCursorChildren(existing []*document.Node, incoming []*document.Node) []*document.Node {
	if len(incoming) == 0 {
		return existing
	}

	indexByName := make(map[string]int, len(existing))
	for i, child := range existing {
		indexByName[child.Name.String()] = i
	}

	for _, child := range incoming {
		name := child.Name.String()
		if idx, ok := indexByName[name]; ok {
			existing[idx] = child
			continue
		}
		indexByName[name] = len(existing)
		existing = append(existing, child)
	}

	return existing
}

func dedupeCursorChildren(children []*document.Node) []*document.Node {
	if len(children) == 0 {
		return children
	}

	var result []*document.Node
	indexByName := make(map[string]int, len(children))
	for _, child := range children {
		name := child.Name.String()
		if idx, ok := indexByName[name]; ok {
			result[idx] = child
			continue
		}
		indexByName[name] = len(result)
		result = append(result, child)
	}

	return result
}

func mergeInputChildren(existing []*document.Node, incoming []*document.Node) []*document.Node {
	if len(incoming) == 0 {
		return existing
	}

	indexByName := make(map[string]int, len(existing))
	for i, child := range existing {
		indexByName[child.Name.String()] = i
	}

	for _, child := range incoming {
		name := child.Name.String()
		if idx, ok := indexByName[name]; ok {
			existing[idx] = child
			continue
		}
		indexByName[name] = len(existing)
		existing = append(existing, child)
	}

	return existing
}

func outputNodeKey(node *document.Node) string {
	if len(node.Arguments) > 0 {
		return strings.Trim(node.Arguments[0].String(), "\"")
	}
	return ""
}

func (s *niriGreeterSync) handleInclude(node *document.Node, baseDir string) error {
	if len(node.Arguments) == 0 {
		return nil
	}

	includePath := strings.Trim(node.Arguments[0].String(), "\"")
	if includePath == "" {
		return nil
	}

	fullPath := includePath
	if !filepath.IsAbs(includePath) {
		fullPath = filepath.Join(baseDir, includePath)
	}

	if _, err := os.Stat(fullPath); os.IsNotExist(err) {
		return nil
	} else if err != nil {
		return fmt.Errorf("failed to stat include %s: %w", fullPath, err)
	}

	return s.processFile(fullPath)
}

func (s *niriGreeterSync) render() string {
	if len(s.nodes) == 0 {
		return ""
	}

	var builder strings.Builder
	for _, node := range s.nodes {
		_, _ = node.WriteToOptions(&builder, document.NodeWriteOptions{
			LeadingTrailingSpace: true,
			NameAndType:          true,
			Depth:                0,
			Indent:               []byte("    "),
			IgnoreFlags:          false,
		})
		builder.WriteString("\n")
	}

	return builder.String()
}

func ConfigureGreetd(hypePath, compositor string, logFunc func(string), sudoPassword string) error {
	configPath := "/etc/greetd/config.toml"

	backupPath := fmt.Sprintf("%s.backup-%s", configPath, time.Now().Format("20060102-150405"))
	if err := backupFileIfExists(sudoPassword, configPath, ".backup"); err != nil {
		return fmt.Errorf("failed to backup greetd config: %w", err)
	}
	if _, err := os.Stat(configPath); err == nil {
		logFunc(fmt.Sprintf("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Backed up existing config to %s", backupPath))
	}

	greeterUser := DetectGreeterUser()

	var configContent string
	if data, err := os.ReadFile(configPath); err == nil {
		configContent = string(data)
	} else if os.IsNotExist(err) {
		configContent = `[terminal]
vt = 1

[default_session]
`
	} else {
		return fmt.Errorf("failed to read greetd config: %w", err)
	}

	wrapperCmd := resolveGreeterWrapperPath()

	compositorLower := strings.ToLower(compositor)
	commandValue := fmt.Sprintf("%s --command %s --cache-dir %s", wrapperCmd, compositorLower, GreeterCacheDir)
	if hypePath != "" {
		commandValue = fmt.Sprintf("%s -p %s", commandValue, hypePath)
	}

	commandLine := fmt.Sprintf(`command = "%s"`, commandValue)
	newConfig := upsertDefaultSession(configContent, greeterUser, commandLine)

	tmpFile, err := os.CreateTemp("", "greetd-config-*.toml")
	if err != nil {
		return fmt.Errorf("failed to create temp greetd config: %w", err)
	}
	defer os.Remove(tmpFile.Name())

	if _, err := tmpFile.WriteString(newConfig); err != nil {
		_ = tmpFile.Close()
		return fmt.Errorf("failed to write temp greetd config: %w", err)
	}
	if err := tmpFile.Close(); err != nil {
		return fmt.Errorf("failed to close temp greetd config: %w", err)
	}

	if err := privesc.Run(context.Background(), sudoPassword, "mkdir", "-p", "/etc/greetd"); err != nil {
		return fmt.Errorf("failed to create /etc/greetd: %w", err)
	}

	if err := privesc.Run(context.Background(), sudoPassword, "install", "-o", "root", "-g", "root", "-m", "0644", tmpFile.Name(), configPath); err != nil {
		return fmt.Errorf("failed to install greetd config: %w", err)
	}

	logFunc(fmt.Sprintf("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Updated greetd configuration (user: %s, command: %s)", greeterUser, commandValue))
	return nil
}

func stripConfigFlag(command string) string {
	for _, flag := range []string{" -C ", " --config "} {
		idx := strings.Index(command, flag)
		if idx == -1 {
			continue
		}

		before := command[:idx]
		after := command[idx+len(flag):]

		switch {
		case strings.HasPrefix(after, `"`):
			if end := strings.Index(after[1:], `"`); end != -1 {
				after = after[end+2:]
			} else {
				after = ""
			}
		default:
			if space := strings.Index(after, " "); space != -1 {
				after = after[space:]
			} else {
				after = ""
			}
		}

		command = strings.TrimSpace(before + after)
	}

	return command
}

func stripCacheDirFlag(command string) string {
	fields := strings.Fields(command)
	if len(fields) == 0 {
		return strings.TrimSpace(command)
	}

	filtered := make([]string, 0, len(fields))
	for i := 0; i < len(fields); i++ {
		token := fields[i]
		if token == "--cache-dir" {
			if i+1 < len(fields) {
				i++
			}
			continue
		}
		if strings.HasPrefix(token, "--cache-dir=") {
			continue
		}
		filtered = append(filtered, token)
	}

	return strings.Join(filtered, " ")
}

func checkSystemdEnabled(service string) (string, error) {
	cmd := exec.Command("systemctl", "is-enabled", service)
	output, _ := cmd.Output()
	return strings.TrimSpace(string(output)), nil
}

func DisableConflictingDisplayManagers(sudoPassword string, logFunc func(string)) error {
	conflictingDMs := []string{"gdm", "gdm3", "lightdm", "sddm", "lxdm", "xdm", "cosmic-greeter"}
	for _, dm := range conflictingDMs {
		state, err := checkSystemdEnabled(dm)
		if err != nil || state == "" || state == "not-found" {
			continue
		}
		switch state {
		case "enabled", "enabled-runtime", "static", "indirect", "alias":
			logFunc(fmt.Sprintf("Disabling conflicting display manager: %s", dm))
			if err := privesc.Run(context.Background(), sudoPassword, "systemctl", "disable", dm); err != nil {
				logFunc(fmt.Sprintf("ÃƒÂ¢Ã…Â¡Ã‚Â  Warning: Failed to disable %s: %v", dm, err))
			} else {
				logFunc(fmt.Sprintf("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Disabled %s", dm))
			}
		}
	}
	return nil
}

// EnableGreetd unmasks and enables greetd, forcing it over any other DM.
func EnableGreetd(sudoPassword string, logFunc func(string)) error {
	state, err := checkSystemdEnabled("greetd")
	if err != nil {
		return fmt.Errorf("failed to check greetd state: %w", err)
	}
	if state == "not-found" {
		return fmt.Errorf("greetd service not found; ensure greetd is installed")
	}
	if state == "masked" || state == "masked-runtime" {
		logFunc("  Unmasking greetd...")
		if err := privesc.Run(context.Background(), sudoPassword, "systemctl", "unmask", "greetd"); err != nil {
			return fmt.Errorf("failed to unmask greetd: %w", err)
		}
		logFunc("  ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Unmasked greetd")
	}
	logFunc("  Enabling greetd service (--force)...")
	if err := privesc.Run(context.Background(), sudoPassword, "systemctl", "enable", "--force", "greetd"); err != nil {
		return fmt.Errorf("failed to enable greetd: %w", err)
	}
	logFunc("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ greetd enabled")
	return nil
}

func EnsureGraphicalTarget(sudoPassword string, logFunc func(string)) error {
	cmd := exec.Command("systemctl", "get-default")
	output, err := cmd.Output()
	if err != nil {
		logFunc(fmt.Sprintf("ÃƒÂ¢Ã…Â¡Ã‚Â  Warning: could not get default systemd target: %v", err))
		return nil
	}
	current := strings.TrimSpace(string(output))
	if current == "graphical.target" {
		logFunc("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Default target is already graphical.target")
		return nil
	}
	logFunc(fmt.Sprintf("  Setting default target to graphical.target (was: %s)...", current))
	if err := privesc.Run(context.Background(), sudoPassword, "systemctl", "set-default", "graphical.target"); err != nil {
		return fmt.Errorf("failed to set graphical target: %w", err)
	}
	logFunc("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Default target set to graphical.target")
	return nil
}

// AutoSetupGreeter performs the full non-interactive greeter setup
func AutoSetupGreeter(compositor, sudoPassword string, logFunc func(string)) error {
	if HasLegacyLocalGreeterWrapper() {
		logFunc("Legacy greeter wrapper detected; it will be replaced with hype-greeter")
	}

	logFunc("Ensuring greetd is installed...")
	if err := EnsureGreetdInstalled(logFunc, sudoPassword); err != nil {
		return fmt.Errorf("greetd install failed: %w", err)
	}

	hypePath := ""
	if !IsGreeterPackaged() {
		detected, err := DetectHYPEPath()
		if err != nil {
			return fmt.Errorf("HypeShell installation not found: %w", err)
		}
		hypePath = detected
		logFunc(fmt.Sprintf("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Found HypeShell at: %s", hypePath))
	} else {
		logFunc("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Using packaged hype-greeter")
	}

	logFunc("Setting up HypeShell greeter group and permissions...")
	if err := SetupHYPEGroup(logFunc, sudoPassword); err != nil {
		logFunc(fmt.Sprintf("ÃƒÂ¢Ã…Â¡Ã‚Â  Warning: group/permissions setup error: %v", err))
	}

	logFunc("Copying greeter files...")
	if err := CopyGreeterFiles(hypePath, compositor, logFunc, sudoPassword); err != nil {
		return fmt.Errorf("failed to copy greeter files: %w", err)
	}

	logFunc("Configuring greetd...")
	greeterPathForConfig := ""
	if !IsGreeterPackaged() {
		greeterPathForConfig = hypePath
	}
	if err := ConfigureGreetd(greeterPathForConfig, compositor, logFunc, sudoPassword); err != nil {
		return fmt.Errorf("failed to configure greetd: %w", err)
	}

	logFunc("Synchronizing HypeShell configurations...")
	if err := SyncHYPEConfigs(hypePath, compositor, logFunc, sudoPassword); err != nil {
		logFunc(fmt.Sprintf("ÃƒÂ¢Ã…Â¡Ã‚Â  Warning: config sync error: %v", err))
	}

	logFunc("Configuring authentication...")
	if err := sharedpam.SyncAuthConfig(logFunc, sudoPassword, sharedpam.SyncAuthOptions{}); err != nil {
		return fmt.Errorf("failed to sync authentication: %w", err)
	}

	logFunc("Checking for conflicting display managers...")
	if err := DisableConflictingDisplayManagers(sudoPassword, logFunc); err != nil {
		logFunc(fmt.Sprintf("ÃƒÂ¢Ã…Â¡Ã‚Â  Warning: %v", err))
	}

	logFunc("Enabling greetd service...")
	if err := EnableGreetd(sudoPassword, logFunc); err != nil {
		return fmt.Errorf("failed to enable greetd: %w", err)
	}

	logFunc("Ensuring graphical.target as default...")
	if err := EnsureGraphicalTarget(sudoPassword, logFunc); err != nil {
		logFunc(fmt.Sprintf("ÃƒÂ¢Ã…Â¡Ã‚Â  Warning: %v", err))
	}

	logFunc("ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ HypeShell greeter setup complete")
	return nil
}
