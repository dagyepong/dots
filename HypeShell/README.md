# HypeShell

<div align="center">
  <a href="https://github.com/acarlton5/HypeShell">
    <img src="assets/hypeshell-logo.svg" alt="HypeShell" width="200">
  </a>

### A modern Hyprland-only desktop shell

Built with [Quickshell](https://quickshell.org/) and [Go](https://go.dev/)

[![Documentation](https://img.shields.io/badge/docs-HypeShell-9ccbfb?style=for-the-badge&labelColor=101418)](https://github.com/acarlton5/HypeShell)
[![GitHub stars](https://img.shields.io/github/stars/acarlton5/HypeShell?style=for-the-badge&labelColor=101418&color=ffd700)](https://github.com/acarlton5/HypeShell/stargazers)
[![GitHub License](https://img.shields.io/github/license/acarlton5/HypeShell?style=for-the-badge&labelColor=101418&color=b9c8da)](https://github.com/acarlton5/HypeShell/blob/main/LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/acarlton5/HypeShell?style=for-the-badge&labelColor=101418&color=9ccbfb)](https://github.com/acarlton5/HypeShell/releases)
[![GitHub](https://img.shields.io/badge/source-GitHub-9ccbfb?style=for-the-badge&logo=github&logoColor=ffffff&labelColor=101418)](https://github.com/acarlton5/HypeShell)

</div>

HypeShell is a complete desktop shell for [Hyprland](https://hyprland.org/), reshaped into a Hyprland-only OS shell with Hype-owned install, plugin, theme, and update paths.

## Repository Structure

This is a monorepo containing both the shell interface and the core backend services:

```
HypeShell/
├── quickshell/         # QML-based shell interface
│   ├── Modules/        # UI components (panels, widgets, overlays)
│   ├── Services/       # System integration (audio, network, bluetooth)
│   ├── Widgets/        # Reusable UI controls
│   └── Common/         # Shared resources and themes
├── core/               # Go backend and CLI
│   ├── cmd/            # hype CLI and hypeinstall binaries
│   ├── internal/       # System integration, IPC, distro support
│   └── pkg/            # Shared packages
├── distro/             # Distribution packaging
│   ├── fedora/         # Fedora RPM specs
│   ├── debian/         # Debian packaging
│   └── nix/            # NixOS/home-manager modules
└── flake.nix           # Nix flake for declarative installation
```

## See it in Action

<div align="center">

https://github.com/user-attachments/assets/1200a739-7770-4601-8b85-695ca527819a

</div>

<details><summary><strong>More Screenshots</strong></summary>

<div align="center">

<img src="https://github.com/user-attachments/assets/203a9678-c3b7-4720-bb97-853a511ac5c8" width="600" alt="Desktop" />

<img src="https://github.com/user-attachments/assets/a937cf35-a43b-4558-8c39-5694ff5fcac4" width="600" alt="Dashboard" />

<img src="https://github.com/user-attachments/assets/2da00ea1-8921-4473-a2a9-44a44535a822" width="450" alt="Launcher" />

<img src="https://github.com/user-attachments/assets/732c30de-5f4a-4a2b-a995-c8ab656cecd5" width="600" alt="Control Center" />

</div>

</details>

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/acarlton5/HypeShell/main/install.sh | bash
```

The installer clones this HypeShell repo, installs missing tools such as Go, make, and Quickshell, builds the shell from source, installs the HypeShell-owned Hyprland session/config files, and can switch SDDM/GDM/LightDM to the HypeShell greeter on `greetd`. It treats Hyprland as the compositor dependency and does not install upstream `hype-shell`, `hype-shell-hyprland`, or `hype-hyprland` packages.

To repair or update an existing install:

```bash
curl -fsSL https://raw.githubusercontent.com/acarlton5/HypeShell/main/install.sh | bash -s -- --update
```

Manual source install on a clean Arch install:

```bash
git clone https://github.com/acarlton5/HypeShell.git
cd HypeShell
./install.sh
```

Manual installation docs will live in this repository while HypeShell's dedicated docs are rebuilt.

## Features

**Dynamic Theming**
Wallpaper-based color schemes that automatically theme GTK, Qt, terminals, editors (vscode, vscodium), and more using [matugen](https://github.com/InioX/matugen) and hype16.

**System Monitoring**
Real-time CPU, RAM, GPU metrics and temperatures with [dgop](https://github.com/AvengeMedia/dgop). Process list with search and management.

**Powerful Launcher**
Spotlight-style search for applications, files ([dsearch](https://github.com/AvengeMedia/hypesearch)), emojis, running windows, calculator, and commands. Extensible with plugins.

**Control Center**
Unified interface for network, Bluetooth, audio devices, display settings, and night mode.

**Smart Notifications**
Notification center with grouping, rich text support, and keyboard navigation.

**Media Integration**
MPRIS player controls, calendar sync, weather widgets, and clipboard history with image previews.

**Session Management**
Lock screen, idle detection, auto-lock/suspend with separate AC/battery settings, and greeter support.

**Plugin System**
Extend functionality with the Hype plugin registry.

## Supported Compositor

HypeShell targets [Hyprland](https://hyprland.org/) only, with workspace switching, overview integration, monitor management, Hyprland keybind parsing, and a HypeShell Hyprland login session installed from this repository.

[Hyprland configuration guide](https://wiki.hypr.land/Configuring/)

## Command Line Interface

Control the shell from the command line or keybinds:

```bash
hype run              # Start the shell
hype ipc call spotlight toggle
hype ipc call audio setvolume 50
hype ipc call wallpaper set /path/to/image.jpg
hype brightness list  # List available displays
hype plugins search   # Browse plugin registry
```

The legacy `hype` command remains as a temporary compatibility alias during the HypeShell transition.

## Documentation

- **Source:** [github.com/acarlton5/HypeShell](https://github.com/acarlton5/HypeShell)
- **Plugins/Themes:** [github.com/acarlton5/HypeRegistry](https://github.com/acarlton5/HypeRegistry)

## Development

See component-specific documentation:

- **[quickshell/](quickshell/)** - QML shell development, widgets, and modules
- **[core/](core/)** - Go backend, CLI tools, and system integration
- **[distro/](distro/)** - Distribution packaging (Fedora, Debian, NixOS)

### Building from Source

**Core + installer:**

```bash
cd core
make              # Build hype CLI
make hypeinstall  # Build installer
```

**Shell:**

```bash
quickshell -p quickshell/
```

**NixOS:**

```nix
{
  inputs.hypeshell.url = "github:acarlton5/HypeShell";

  # Use in home-manager or NixOS configuration
  imports = [ inputs.hypeshell.homeModules.hypeshell ];
}
```

## Contributing

Contributions welcome. Bug fixes, widgets, features, documentation, and plugins all help.

1. Fork the repository
2. Make your changes
3. Test thoroughly
4. Open a pull request

For documentation contributions, open a pull request in this repository.

## Credits

- [quickshell](https://quickshell.org/) - Shell framework
- [niri](https://github.com/YaLTeR/niri) - Scrolling window manager
- [Ly-sec](http://github.com/ly-sec) - Wallpaper effects from [Noctalia](https://github.com/noctalia-dev/noctalia-shell)
- [soramanew](https://github.com/soramanew) - [Caelestia](https://github.com/caelestia-dots/shell) inspiration
- [end-4](https://github.com/end-4) - [dots-hyprland](https://github.com/end-4/dots-hyprland) inspiration

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=acarlton5/HypeShell&type=date&legend=top-left)](https://www.star-history.com/#acarlton5/HypeShell&type=date&legend=top-left)

## License

MIT License - See [LICENSE](LICENSE) for details.
