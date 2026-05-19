# Hype (hype) Greeter

A greeter for [greetd](https://github.com/kennylevinsen/greetd) that follows the aesthetics of the hype lock screen.

## Features

- **Multi user**: Login with any system user
- **hype sync**: Sync settings with hype for consistent styling between shell and greeter
- **Multiple compositors**: The `hype-greeter` wrapper supports niri, Hyprland, sway, scroll, miracle-wm, labwc, and mangowc.
- **Custom PAM**: Supports custom PAM configuration in `/etc/pam.d/greetd`
- **Session Memory**: Remembers last selected session and user
  - Can be disabled via `settings.json` keys: `greeterRememberLastSession` and `greeterRememberLastUser`

## Installation

### Arch Linux

Arch linux users can install [greetd-hype-greeter-git](https://aur.archlinux.org/packages/greetd-hype-greeter-git) from the AUR.

```bash
paru -S greetd-hype-greeter-git
# Or with yay
yay -S greetd-hype-greeter-git
```

### Debian / openSUSE

Official packages are available from the [HypeLinux OBS repository](https://software.opensuse.org/download/package?package=hype-greeter&project=home%3AAvengeMedia%3Ahypelinux). Add the repo for your distribution and install:

```bash
# Debian 13
sudo apt install hype-greeter   # after adding the repo

# openSUSE Tumbleweed
zypper install hype-greeter     # after adding the repo
```

See the [Installation guide](https://hypelinux.com/docs/hypegreeter/installation) for full repository setup.

If you previously installed manually, remove legacy files first:

```bash
sudo rm -f /usr/local/bin/hype-greeter
sudo rm -rf /etc/xdg/quickshell/hype-greeter
```

Then complete setup:

```bash
hype greeter enable
hype greeter sync
```

#### Syncing themes (Optional)

To sync your wallpaper and theme with the greeter login screen, follow the manual setup below:

<details>
<summary>Manual theme syncing</summary>

```bash
# Add yourself to greeter group
sudo usermod -aG greeter <username>

# Set ACLs to allow greeter to traverse your directories
setfacl -m u:greeter:x ~ ~/.config ~/.local ~/.cache ~/.local/state

# Set group ownership on config directories
sudo chgrp -R greeter ~/.config/HypeMaterialShell
sudo chgrp -R greeter ~/.local/state/HypeMaterialShell
sudo chgrp -R greeter ~/.cache/HypeMaterialShell
sudo chmod -R g+rX ~/.config/HypeMaterialShell ~/.cache/HypeMaterialShell ~/.cache/quickshell

# Create symlinks
sudo ln -sf ~/.config/HypeMaterialShell/settings.json /var/cache/hype-greeter/settings.json
sudo ln -sf ~/.local/state/HypeMaterialShell/session.json /var/cache/hype-greeter/session.json
sudo ln -sf ~/.cache/HypeMaterialShell/hype-colors.json /var/cache/hype-greeter/colors.json

# Logout and login for group membership to take effect
```

</details>

### Fedora / RHEL / Rocky / Alma

Install from COPR or build the RPM:

```bash
# From COPR (when available)
sudo dnf copr enable avenge/hype
sudo dnf install hype-greeter

# Or build locally
cd /path/to/HypeMaterialShell
rpkg local
sudo rpm -ivh x86_64/hype-greeter-*.rpm
```

The package automatically:
- Creates the greeter user
- Sets up directories and permissions
- Configures greetd with auto-detected compositor
- Applies SELinux contexts

Then complete setup:

```bash
hype greeter enable
hype greeter sync
```

#### Syncing themes (Optional)

Run:

```bash
hype greeter sync
```

Then logout/login to see your wallpaper on the greeter.

### Automatic

The easiest thing is to run `hype greeter install` or `hype` for interactive installation.
On Debian/openSUSE, this now prefers the `hype-greeter` package when the OBS repo is configured.

### Manual (fallback only)

Use this only if no package is available for your distro.

1. Install `greetd` (in most distro's standard repositories) and `quickshell`

2. Create the greeter user (if not already created by greetd):
```bash
sudo groupadd -r greeter
sudo useradd -r -g greeter -d /var/lib/greeter -s /bin/bash -c "System Greeter" greeter
sudo mkdir -p /var/lib/greeter
sudo chown greeter:greeter /var/lib/greeter
```

3. Clone the hype project to `/etc/xdg/quickshell/hype-greeter`:
```bash
sudo git clone https://github.com/AvengeMedia/HypeMaterialShell.git /etc/xdg/quickshell/hype-greeter
```

4. Copy `Modules/Greetd/assets/hype-greeter` to `/usr/local/bin/hype-greeter`:
```bash
sudo cp /etc/xdg/quickshell/hype-greeter/Modules/Greetd/assets/hype-greeter /usr/local/bin/hype-greeter
sudo chmod +x /usr/local/bin/hype-greeter
```

5. Create greeter cache directory with proper permissions:
```bash
sudo mkdir -p /var/cache/hype-greeter
sudo chown <greeter-user>:<greeter-group> /var/cache/hype-greeter
sudo chmod 2770 /var/cache/hype-greeter
```

6. Edit or create `/etc/greetd/config.toml`:
```toml
[terminal]
vt = 1

[default_session]
user = "greeter"
# Change compositor to another wrapper-supported compositor if preferred
command = "/usr/local/bin/hype-greeter --command niri"
```

7. Disable existing display manager and enable greetd:
```bash
sudo systemctl disable gdm sddm lightdm
sudo systemctl enable greetd
```

8. (Optional) Set up theme syncing using the manual ACL method described in the Configuration → Personalization section below

#### Legacy installation (deprecated)

If you prefer the old method with separate shell scripts and config files:
1. Copy `assets/hype-niri.kdl` or `assets/hype-hypr.conf` to `/etc/greetd`
2. Copy `assets/greet-niri.sh` or `assets/greet-hyprland.sh` to `/usr/local/bin/start-hype-greetd.sh`
3. Edit the config file and replace `_HYPE_PATH_` with your HYPE installation path
4. Configure greetd to use `/usr/local/bin/start-hype-greetd.sh`

### NixOS

To install the greeter on NixOS add the repo to your flake inputs as described in the readme. Then somewhere in your NixOS config add this to imports:
```nix
imports = [
  inputs.hype-material-shell.nixosModules.greeter
]
```

Enable the greeter with this in your NixOS config:
```nix
programs.hype-material-shell.greeter = {
  enable = true;
  compositor.name = "niri"; # or set to hyprland
  configHome = "/home/user"; # optionally copyies that users HYPE settings (and wallpaper if set) to the greeters data directory as root before greeter starts
};
```

## Usage

### Using hype-greeter wrapper (recommended)

The `hype-greeter` wrapper simplifies running the greeter with any compositor:

```bash
hype-greeter --command niri
hype-greeter --command hyprland
hype-greeter --command sway
hype-greeter --command mangowc
hype-greeter --command niri -C /path/to/custom-niri.kdl
hype-greeter --command niri --remember-last-user false --remember-last-session false
```

Configure greetd to use it in `/etc/greetd/config.toml`:
```toml
[terminal]
vt = 1

[default_session]
user = "greeter"
command = "/usr/bin/hype-greeter --command niri"
```

### Manual usage

To run hype in greeter mode you can also manually set environment variables:

```bash
HYPE_RUN_GREETER=1 qs -p /path/to/hype
```

### Configuration

#### Compositor

For current wrapper-based installs, the `hype-greeter` wrapper supports niri, hyprland, sway, scroll, miracle-wm, labwc, and mangowc.

Only niri currently has a generated greeter config path managed by `hype greeter sync`.

- niri: `hype greeter sync` writes the generated greeter config to `/etc/greetd/niri/config.kdl`. Add local manual tweaks in `/etc/greetd/niri_overrides.kdl`.
- Other wrapper-supported compositors use the wrapper-generated config by default. If you need a custom compositor config, add `-C /path/to/config` to the `hype-greeter` command in `/etc/greetd/config.toml`.

#### Personalization

The greeter can be personalized with wallpapers, themes, weather, clock formats, and more - configured exactly the same as hype.

**Easiest method:** Run `hype greeter sync` to automatically sync your HypeShell theme with the greeter.

**Manual method:** You can manually synchronize configurations if you want greeter settings to always mirror your shell:

```bash
# Add yourself to the greeter group
sudo usermod -aG greeter $USER

# Set ACLs to allow greeter user to traverse your home directory
setfacl -m u:greeter:x ~ ~/.config ~/.local ~/.cache ~/.local/state

# Set group permissions on HYPE directories
sudo chgrp -R greeter ~/.config/HypeMaterialShell ~/.local/state/HypeMaterialShell ~/.cache/quickshell
sudo chmod -R g+rX ~/.config/HypeMaterialShell ~/.local/state/HypeMaterialShell ~/.cache/quickshell

# Create symlinks for theme files
sudo ln -sf ~/.config/HypeMaterialShell/settings.json /var/cache/hype-greeter/settings.json
sudo ln -sf ~/.local/state/HypeMaterialShell/session.json /var/cache/hype-greeter/session.json
sudo ln -sf ~/.cache/HypeMaterialShell/hype-colors.json /var/cache/hype-greeter/colors.json

# Logout and login for group membership to take effect
```

**Advanced:** You can override the configuration path with the `HYPE_GREET_CFG_DIR` environment variable or the `--cache-dir` flag when using `hype-greeter`. The default is `/var/cache/hype-greeter`.

The cache directory should be owned by `<greeter-user>:<greeter-group>` with `2770` permissions. If the greeter user is not available yet, HYPE falls back to `root:<greeter-group>`.
