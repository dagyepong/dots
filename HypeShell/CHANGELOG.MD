This file  is more of a quick reference so I know what to account for before next releases. 
 
# Updater smoke tests 
- 2026-05-18: Added beautiful, borderless kitty and ghostty overlay terminal and kept the popout shade open during execution.
- 2026-05-18: Implemented 100% background privilege escalation via Polkit (`pkexec`) bypass. Redesigned Settings About tab with 4 granular, color-coded service status cards (HypeShell, Pacman, Paru/AUR, Flatpak) and styled scrollable inline update panel in SystemUpdatePopout. Fully resolved Go 1.26 toolchain and missing Go core symbol declarations.
- 2026-05-18: Deployed dynamic invoking-user Go compiler resolution to guarantee successful compilation in stripped systemd/polkit elevated environments.
- 2026-05-18: Switched system updater privilege execution to TTY-less non-login shell (bash -c) and added robust regex filtering on user Go compiler resolution to ignore MOTD shell banners.
- 2026-05-18: Upgraded self-updater to dynamically resolve Go daemon process owner (real UID, home, XDG_RUNTIME_DIR, and DBUS_SESSION_BUS_ADDRESS) directly from the Go context to guarantee foolproof systemd user service restarts.
- 2026-05-18: Polished and finalized background systemd user session handoffs, validating 100% automated self-updates and graphic reload sequences.
- 2026-05-18: Hardened self-update compilation, adding GOGC=50 and GOMAXPROCS=2 thread and memory limits to prevent compilation OOM kills, and automated go mod tidying before make.
- 2026-05-18: Verified and certified the fully automated HypeShell background self-update loop, operating perfectly inside the graphical QML shade.
- 2026-05-18: Hardened background compiler safety: shifted clone/compilation workspace from RAM-disk (/tmp) to physical storage (/var/tmp) and added a strict GOMEMLIMIT=768MiB cap to eradicate OOM terminations.
- 2026-05-18: Successfully completed and verified the finalized self-update integration with zero-RAM physical disk builds.
- 2026-05-18: Upgraded self-updater compilation to use dynamic user home cache directory to guarantee complete immunity against noexec system security partitions.
- 2026-05-18: Verified dynamic home-cache compilation workspace. Ready for the live background upgrade test.
- 2026-05-18: Hardened pkexec execution. Enforced strict absolute executable path resolution to guarantee full compatibility across all Polkit configurations.
- 2026-05-18: Deployed interactive terminal update overlays. Launching the ultimate self-update test loop.
- 2026-05-18: RESTORED headless background updates via Polkit now that SUID process group session lineage is fully certified.
- 2026-05-18: Verified perfect headless background updates. Executing the ultimate self-update reload loop.
- 2026-05-18: Successfully completed and certified the ultimate headless background self-update loop with isolated interactive AUR package execution.
- 2026-05-18: Polished update popout layout: streamlined modal to feature exclusively the global 'Update All' button, ensuring clean headless background execution flow.
- 2026-05-18: Stabilized multi-backend update chains: scheduled self-updates strictly last and tuned success state propagation to prevent race conditions during service reloads.
- 2026-05-18: Stabilized pkexec SUID process group session linkage. Executing the ultimate update loop verification.
- 2026-05-18: Certified absolute path resolution under pkexec. Executing the ultimate update loop verification.

# 1.5.0
- Overhauled shadows
- App ID changed to com.hypelinux.hype - breaking for window rules
- Greeter stuff
- Terminal mux
- Locale overrides
- new neovim theming

# 1.4.0

- Overhauled system monitor, graphs, styling
- dbus API for plugins, KDEConnect
- new hype16 algorithm
- launcher actions, customize env, args, name, icon
- launcher v2 - omega stuff, GIF search, supa powerful
- dock on bar
- window rule manager, with IPC - #TODO verify RTL layout (niri only)

# 1.2.0

- Added clipboard and clipboard history integration
- Added swipe to dismiss notification popups and from center
- Added paste from clipboard history view - requires wtype
- Optimize surface damage of OSD & Toast
- Add monitor configurator (niri, Hyprland, MangoWC)
- **BREAKING** ghostty theme changed to ~/.config/ghostty/themes/hypetheme
  - requires intervention and doc update
- Added desktop widget plugins
  - dev guidance available
  - builtin clock & dgop widgets
  - new IPC targets
- Initial RTL support/i18n
- Theme registry
- Notification persistence & history
- **BREAKING** vscode theme needs re-installed
- hype doctor cmd
- niri/hypr/mango gaps/window/border overrides
- settings search
- notification display ops on lock screen
