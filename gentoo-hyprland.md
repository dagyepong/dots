# Gentoo Hyprland NVIDIA with Bcachefs Integration Guide

## Overview

This comprehensive guide details the installation of Hyprland with NVIDIA drivers on Gentoo Linux, with specialized integration for bcachefs root filesystem. The guide maintains the original minimal installation philosophy while adding modern bcachefs support through Gentoo's config snippets methodology.

## System Environment

**Target System**: `sam@gentoo.local:/mnt/gentoo`

**Bcachefs Array Configuration**:
- **UUID**: `26cfc62d-b966-417f-bee4-76cf4ea0c557`
- **Version**: 1.25
- **Compression**: zstd
- **Metadata replicas**: 3
- **Data replicas**: 2
- **Devices**: 5-device multi-tier array
  - nvme0: 466 GB NVMe SSD
  - nvme2: 932 GB NVMe SSD  
  - nvme3: 1.82 TB NVMe SSD
  - hdd1: 5.46 TB HDD
  - hdd2: 5.46 TB HDD

## Installation Phases

### Phase 1: Environment Setup

**Objectives**: Initialize chroot environment and system variables

```bash
# Source environment and set chroot prompt
source /etc/profile && export PS1="(chroot) ${PS1}"

# Mount boot partition (adjust device path as needed)
mount /dev/nvme0n1p1 /boot

# Initialize system variables
PARTITION_ROOT=$(findmnt -n -o SOURCE /) 
PARTITION_BOOT=$(findmnt -n -o SOURCE /boot)  
UUID_ROOT=$(blkid -s UUID -o value $PARTITION_ROOT) 
UUID_BOOT=$(blkid -s UUID -o value $PARTITION_BOOT) 
PARTUUID_ROOT=$(blkid -s PARTUUID -o value $PARTITION_ROOT)

# Interactive configuration
read -p "Enter the timezone (eg. Europe/Berlin): " time_zone
read -p "Enter the new username: " username
read -s -p "Enter the new password: " password
```

### Phase 2: Portage Repository Configuration

**Objectives**: Sync repositories and configure locale settings

```bash
# Sync Gentoo repository
emerge --sync --quiet

# Configure locale settings
sed -i "s/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g" /etc/locale.gen
locale-gen
eselect locale set en_US.utf8
echo "LC_COLLATE=\"C.UTF-8\"" >> /etc/env.d/02locale

# Update environment
env-update && source /etc/profile && export PS1="(chroot) ${PS1}"
```

### Phase 3: Make.conf Configuration

**Objectives**: Configure Portage for optimal compilation and bcachefs support

#### CPU Flags Detection
```bash
emerge cpuid2cpuflags
cpuid2cpuflags | sed 's/:\s/="/; s/$/"/' >> /etc/portage/make.conf
```

#### Core Configuration
```bash
# License acceptance
echo "ACCEPT_LICENSE=\"*\"" >> /etc/portage/make.conf

# NVIDIA graphics
echo "VIDEO_CARDS=\"nvidia\"" >> /etc/portage/make.conf

# Parallel compilation
echo "MAKEOPTS=\"-j$(nproc) -l$(nproc)\"" >> /etc/portage/make.conf
echo "PORTAGE_SCHEDULING_POLICY=\"idle\"" >> /etc/portage/make.conf
echo "EMERGE_DEFAULT_OPTS=\"--jobs=$(nproc) --load-average=$(nproc) --keep-going --verbose --quiet-build --with-bdeps=y --complete-graph=y --deep --ask\"" >> /etc/portage/make.conf
```

#### Package Keywords and Targets
```bash
cat << EOF >> /etc/portage/make.conf
ACCEPT_KEYWORDS="~amd64"
RUBY_TARGETS="ruby31"
RUBY_SINGLE_TARGET="ruby31"
PYTHON_TARGETS="python3_11"
PYTHON_SINGLE_TARGET="python3_11"
LUA_TARGETS="lua5-4"
LUA_SINGLE_TARGET="lua5-4"
EOF
```

#### Portage Features
```bash
echo "FEATURES=\"candy fixlafiles unmerge-orphans noman nodoc noinfo notitles parallel-install parallel-fetch clean-logs\"" >> /etc/portage/make.conf
```

#### Global USE Flags
```bash
echo "USE=\"-* minimal wayland pipewire vulkan clang qt6 native-symlinks lto pgo jit xs orc threads asm openmp system-man system-libyaml system-lua system-bootstrap system-llvm system-lz4 system-sqlite system-ffmpeg system-icu system-av1 system-harfbuzz system-jpeg system-libevent system-librnp system-libvpx system-png system-python-libs system-webp system-ssl system-zlib system-boost\"" >> /etc/portage/make.conf
```

#### Compiler Flags
```bash
# Update COMMON_FLAGS
sed -i "s/COMMON_FLAGS=.*/COMMON_FLAGS=\"-march=native -O2 -pipe\"/g" /etc/portage/make.conf

# Add LDFLAGS
sed -i '/^FFLAGS/ a\LDFLAGS=\"-Wl,-O2 -Wl,--as-needed\"' /etc/portage/make.conf

# Add RUSTFLAGS
sed -i '/^LDFLAGS/ a\RUSTFLAGS=\"-C debuginfo=0 -C codegen-units=1 -C target-cpu=native -C opt-level=3\"' /etc/portage/make.conf
```

### Phase 4: Package Configuration

#### Package USE Flags
```bash
rm -rf /etc/portage/package.use
curl -L https://gist.githubusercontent.com/emrakyz/0361625a94f5317345b8a7934dbb350b/raw/c28c982bf681436eaec846a80dce2890356584af/package.use -o /etc/portage/package.use
```

#### Package Accept Keywords
```bash
rm -rf /etc/portage/package.accept_keywords
curl -L https://gist.githubusercontent.com/emrakyz/7cd145c59e431046ecaea0666ce6d734/raw/894ab89518e6c33719c6208155b6de90c3c81ac5/package.accept_keywords -o /etc/portage/package.accept_keywords
```

#### Qt6 Unmasking
```bash
echo "-qt6" > /etc/portage/profile/use.mask

cat << EOF > /etc/portage/profile/package.unmask
dev-qt/qtgui
dev-qt/qtchooser
dev-qt/qtdbus
dev-qt/qtcore
dev-qt/qtbase
dev-qt/qtwayland
dev-qt/qtdeclarative
dev-qt/qtshadertools
dev-qt/qtsvg
dev-qt/qttools
dev-qt/qt5compat
dev-qt/qtimageformats
media-video/ffmpeg
virtual/rust
dev-lang/rust
EOF
```

#### Firefox Compiler Environment (Optional)
```bash
mkdir -p /etc/portage/env
curl -L https://gist.githubusercontent.com/emrakyz/23bf6fe9c30aa0b1eb88021889750ace/raw/832a0160ac0d0383c4f600da5cf8af4290019ff6/compiler-firefox -o /etc/portage/env/compiler-firefox
echo "www-client/firefox compiler-firefox" > /etc/portage/package.env
```

### Phase 5: System Update and Bcachefs Tools

**Objectives**: Update system and install bcachefs requirements

```bash
# Install bcachefs tools first
emerge sys-fs/bcachefs-tools

# System update
emerge --update --newuse @world
emerge @preserved-rebuild
emerge --depclean

# Update environment
env-update && source /etc/profile && export PS1="(chroot) ${PS1}"
```

### Phase 6: System Configuration

#### Timezone Configuration
```bash
rm /etc/localtime
echo "$time_zone" > /etc/timezone
emerge --config sys-libs/timezone-data
```

#### CPU Microcode (Intel)
```bash
# Temporary signature detection
echo "MICROCODE_SIGNATURES=\"-S\"" >> /etc/portage/make.conf
emerge intel-microcode

# Get signature and update
SIGNATURE=$(iucode_tool -S 2>&1 | grep -o "0.*$")
sed -i "s/MICROCODE_SIGNATURES=\"-S\"/MICROCODE_SIGNATURES=\"-s $SIGNATURE\"/" /etc/portage/make.conf
emerge intel-microcode
```

#### Linux Firmware Optimization
```bash
USE="-compress-xz" emerge linux-firmware
emerge --oneshot pciutils

# GPU-specific firmware stripping
GPU_CODE=$(lspci | grep -i 'vga\|3d\|2d' | awk -F'[[]' '{print $1}' | awk '{print $NF}' | tr '[:upper:]' '[:lower:]')
sed -i "/^nvidia\/\($GPU_CODE\)/!d" /etc/portage/savedconfig/sys-kernel/linux-firmware-*
```

#### Freetype Dependencies
```bash
USE="-harfbuzz" emerge --oneshot freetype
emerge --oneshot freetype
```

### Phase 7: Kernel Configuration with Bcachefs Integration

**Objectives**: Configure minimal kernel with bcachefs support using config snippets

#### Setup Config Snippets Directory
```bash
mkdir -p /etc/kernel/config.d
```

#### Install Base Kernel
```bash
emerge gentoo-sources
cd /usr/src/linux

# Download base minimal configuration
curl -L https://gist.githubusercontent.com/emrakyz/0ff8674792bd844fcab6afb2063ffa94/raw/e91e60ae2f74ccee8fcd7b7b93db942ba60277ce/.config -o .config
```

#### Create Bcachefs Config Snippet
```bash
cat << 'EOF' > /etc/kernel/config.d/bcachefs.config
# Bcachefs filesystem support
CONFIG_BCACHEFS_FS=y
CONFIG_BCACHEFS_POSIX_ACL=y
CONFIG_BCACHEFS_QUOTA=y

# Required crypto support for bcachefs
CONFIG_CRC32C=y
CONFIG_XXHASH=y
CONFIG_CRYPTO_LZ4=y
CONFIG_CRYPTO_ZSTD=y
CONFIG_KEYS=y

# Additional crypto options for bcachefs encryption (optional)
CONFIG_CRYPTO_BLAKE2B=y
CONFIG_CRYPTO_CHACHA20=y
CONFIG_CRYPTO_POLY1305=y
EOF
```

#### Kernel Customization for Bcachefs
```bash
# Update command line for bcachefs root
sed -i "s#CONFIG_CMDLINE=\"root=PARTUUID=.*\"#CONFIG_CMDLINE=\"root=UUID=$UUID_ROOT rootfstype=bcachefs rootwait\"#g" /usr/src/linux/.config

# Update microcode path
MICROCODE_PATH=$(iucode_tool -S -l /lib/firmware/intel-ucode/* 2>&1 | grep 'microcode bundle' | awk -F': ' '{print $2}' | cut -d'/' -f4-)
sed -i "s#CONFIG_EXTRA_FIRMWARE=.*#CONFIG_EXTRA_FIRMWARE=\"$MICROCODE_PATH\"#g" /usr/src/linux/.config

# Update CPU thread count
THREAD_NUM=$(nproc)
sed -i "s#CONFIG_NR_CPUS=.*#CONFIG_NR_CPUS=$THREAD_NUM#g" /usr/src/linux/.config
```

#### Merge Configuration and Compile
```bash
# Merge base config with bcachefs fragment
scripts/kconfig/merge_config.sh .config /etc/kernel/config.d/bcachefs.config

# Final configuration
make olddefconfig
make menuconfig  # Optional: review merged configuration

# Install installkernel for automated handling
emerge sys-kernel/installkernel

# Compile kernel
make -j$(nproc)
make modules_install
make install
```

#### NVIDIA Drivers and Firmware
```bash
emerge nvidia-drivers linux-firmware
```

### Phase 8: Boot Configuration

#### Efistub Setup
```bash
# Create EFI boot directory
mkdir -p /boot/EFI/BOOT

# Copy kernel binary
cp /usr/src/linux/arch/x86/boot/bzImage /boot/EFI/BOOT/BOOTX64.EFI
```

#### Fstab Configuration for Bcachefs
```bash
cat << EOF > /etc/fstab
UUID=$UUID_ROOT / bcachefs defaults 0 0
UUID=$UUID_BOOT /boot vfat defaults,noatime 0 2
EOF
```

### Phase 9: Network and User Setup

#### Network Configuration
```bash
# Hostname
sed -i "s/hostname=.*/hostname=\"$username\"/g" /etc/conf.d/hostname

# Network services
emerge net-misc/dhcpcd 
rc-update add dhcpcd default 
rc-service dhcpcd start

# Hosts file
echo -e "127.0.0.1\t$username\tlocalhost\n::1\t\t$username\tlocalhost" > /etc/hosts

# Optional: StevenBlack hosts for ad blocking
curl -s https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling/hosts | tail -n +40 >> /etc/hosts
```

#### User Management
```bash
# Remove hard password requirements
sed -i 's/enforce=everyone/enforce=none/g' /etc/security/passwdqc.conf

# Set passwords
echo "root:$password" | chpasswd

# Configure doas instead of sudo
emerge doas
cat << EOF > /etc/doas.conf
permit :wheel
permit nopass keepenv :$username
permit nopass keepenv :root
EOF

# Optional DNS configuration
echo -e "nameserver 9.9.9.9\nnameserver 149.112.112.112" > /etc/resolv.conf
echo "nohook resolv.conf" >> /etc/dhcpcd.conf
```

### Phase 10: Repository Management

```bash
# Install repository tools
emerge app-eselect/eselect-repository dev-vcs/git

# Remove rsync repo, add git-based
eselect repository remove gentoo && rm -rf /var/db/repos/gentoo
eselect repository add gentoo git https://github.com/gentoo-mirror/gentoo.git

# Enable additional repositories
eselect repository enable wayland-desktop guru pf4public

# Create local repository for Hyprland
eselect repository create local
mkdir -p /var/db/repos/local/gui-wm/hyprland/files

# Download Hyprland ebuild and NVIDIA patch
curl -L https://gist.githubusercontent.com/emrakyz/eeab3c83fb527bae2f52930e86ac3768/raw/66f5ef7c9f4e0480d46749018f6cccb60fecfa15/hyprland-9999.ebuild -o /var/db/repos/local/gui-wm/hyprland/hyprland-9999.ebuild
curl -L https://gist.githubusercontent.com/emrakyz/2c7c8da8295e0671f676cb0c2951b3e9/raw/67de071d1c08aecc995f7d0407038d537c4e2666/nvidia-9999.patch -o /var/db/repos/local/gui-wm/hyprland/files/nvidia-9999.patch

# Set ownership and create manifest
chown -R portage:portage /var/db/repos/local
ebuild /var/db/repos/local/gui-wm/hyprland/hyprland-9999.ebuild manifest
```

### Phase 11: Package Installation

```bash
# Install desktop environment packages
emerge gui-wm/hyprland::local kitty wofi dunst imv doas gnome-base/gsettings-desktop-schemas hyprpaper wl-clipboard xdg-desktop-portal-hyprland dhcpcd efibootmgr
```

### Phase 12: Service Management

**Critical**: These services are essential for Wayland functionality

```bash
# Add critical services
rc-update add seatd default    # Required for Wayland login sessions
rc-update add dhcpcd default   # Network connectivity
rc-service dhcpcd start
```

### Phase 13: User Creation

```bash
# Create user with required groups
useradd -mG wheel,audio,video,usb,input,portage,pipewire,seat $username
echo "$username:$password" | chpasswd
```

### Phase 14: Hyprland Configuration

#### Base Configuration
```bash
# Create config directory
mkdir -p /home/$username/.config/hypr

# Download reference configuration
curl -L https://raw.githubusercontent.com/hyprwm/Hyprland/3229862dd4cbfa93638a4d16ed86ec2fda5d38a6/example/hyprland.conf -o /home/$username/.config/hypr/hyprland.conf
```

#### NVIDIA-Specific Environment Variables
```bash
cat << 'EOF' >> /home/$username/.config/hypr/hyprland.conf

# Execution
exec-once=dbus-launch gentoo-pipewire-launcher & hyprpaper
exec-once=/home/$username/.config/hypr/portalstart

# NVIDIA optimizations
misc {
    disable_hyprland_logo=1
    disable_splash_rendering=1
}

# Environment variables
env = QT_SCREEN_SCALE_FACTORS,1;1
env = WLR_NO_HARDWARE_CURSORS,1
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = _JAVA_AWT_WM_NONREPARENTING,1
env = ANV_QUEUE_THREAD_DISABLE,1
env = QT_QPA_PLATFORM,wayland
env = CLUTTER_BACKEND,wayland
env = SDL_VIDEODRIVER,wayland
env = XDG_SESSION_TYPE,wayland
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_DESKTOP,Hyprland
env = MOZ_ENABLE_WAYLAND,1
env = MOZ_DBUS_REMOTE,1
EOF
```

#### Portal Startup Script
```bash
cat << 'EOF' > /home/$username/.config/hypr/portalstart
#!/bin/bash
sleep 1
killall xdg-desktop-portal-hyprland
killall xdg-desktop-portal-wlr
killall xdg-desktop-portal
/usr/libexec/xdg-desktop-portal-hyprland &
sleep 2
/usr/libexec/xdg-desktop-portal &
EOF

chmod +x /home/$username/.config/hypr/portalstart
```

#### Hyprland Startup Script
```bash
cat << 'EOF' > /home/$username/.config/hypr/start.sh
#!/bin/sh
cd ~
export XDG_RUNTIME_DIR="/tmp/hyprland"
mkdir -p $XDG_RUNTIME_DIR
chmod 0700 $XDG_RUNTIME_DIR
exec dbus-launch --exit-with-session Hyprland
EOF

chmod +x /home/$username/.config/hypr/start.sh
```

### Phase 15: NVIDIA Modules Configuration

**Critical**: NVIDIA modules must load automatically at boot

```bash
mkdir -p /etc/modules-load.d
cat << 'EOF' > /etc/modules-load.d/video.conf
nvidia
nvidia_modeset
nvidia_uvm
nvidia_drm
EOF
```

### Phase 16: Auto-Start Configuration

Add to shell profile (e.g., ~/.zshrc or ~/.bashrc):
```bash
[ "$(tty)" = "/dev/tty1" ] && ! pidof -s Hyprland >/dev/null 2>&1 && exec "/home/$username/.config/hypr/start.sh"
```

### Phase 17: Font Configuration

```bash
eselect fontconfig disable 10-hinting-slight.conf
eselect fontconfig disable 10-no-antialias.conf
eselect fontconfig disable 10-sub-pixel-none.conf
eselect fontconfig enable 10-hinting-full.conf
eselect fontconfig enable 10-sub-pixel-rgb.conf
eselect fontconfig enable 10-yes-antialias.conf
eselect fontconfig enable 11-lcdfilter-default.conf
```

### Phase 18: System Cleanup

```bash
rm -rf /var/tmp/portage/*
rm -rf /var/cache/distfiles/*
rm -rf /var/cache/binpkgs/*
```

### Phase 19: Boot Entry Creation

**Important**: Adjust device paths for your system

```bash
# Example - modify device paths as needed
efibootmgr -c -d /dev/nvme0n1 -p 1 -L "GENTOO" -l '\EFI\BOOT\BOOTX64.EFI'

# Remove efibootmgr after success
emerge --depclean efibootmgr && emerge --depclean
```

## Bcachefs-Specific Considerations

### Multi-Device Array Handling
- **rootwait parameter**: Ensures all 5 devices are available before mounting
- **UUID-based mounting**: More reliable than device paths for multi-device arrays
- **Device discovery delays**: May need rootdelay parameter for slow device initialization

### Boot Process
- **Initramfs requirement**: Bcachefs root requires initramfs for proper mounting
- **Config snippets**: Modular kernel configuration for maintainability
- **efistub compatibility**: Works with bcachefs using proper UUID parameters

### Troubleshooting
- **Common issue**: bcachefs binary not found in initramfs
- **Check contents**: `lsinitrd /boot/initramfs`
- **Verify module**: Ensure CONFIG_BCACHEFS_FS=y (built-in)
- **Emergency boot**: Use external media and chroot to fix issues

## Post-Installation

After successful boot into Hyprland:

### GTK Settings Configuration
```bash
# Example gsettings commands (run after Hyprland starts)
gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita'
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
```

### MPV Configuration for Wayland
Create `~/.config/mpv/mpv.conf`:
```
gpu-api=vulkan
vo=gpu-next
hwdec=nvdec
profile=gpu-hq
```

## Key Resources

### Configuration Files
- **Kernel config**: https://gist.githubusercontent.com/emrakyz/0ff8674792bd844fcab6afb2063ffa94/raw/e91e60ae2f74ccee8fcd7b7b93db942ba60277ce/.config
- **Package USE flags**: https://gist.githubusercontent.com/emrakyz/0361625a94f5317345b8a7934dbb350b/raw/c28c982bf681436eaec846a80dce2890356584af/package.use
- **Package keywords**: https://gist.githubusercontent.com/emrakyz/7cd145c59e431046ecaea0666ce6d734/raw/894ab89518e6c33719c6208155b6de90c3c81ac5/package.accept_keywords
- **Firefox compiler env**: https://gist.githubusercontent.com/emrakyz/23bf6fe9c30aa0b1eb88021889750ace/raw/832a0160ac0d0383c4f600da5cf8af4290019ff6/compiler-firefox

### Hyprland Resources
- **Custom ebuild**: https://gist.githubusercontent.com/emrakyz/eeab3c83fb527bae2f52930e86ac3768/raw/66f5ef7c9f4e0480d46749018f6cccb60fecfa15/hyprland-9999.ebuild
- **NVIDIA patch**: https://gist.githubusercontent.com/emrakyz/2c7c8da8295e0671f676cb0c2951b3e9/raw/67de071d1c08aecc995f7d0407038d537c4e2666/nvidia-9999.patch
- **Reference config**: https://raw.githubusercontent.com/hyprwm/Hyprland/3229862dd4cbfa93638a4d16ed86ec2fda5d38a6/example/hyprland.conf

### External Resources
- **StevenBlack hosts**: https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling/hosts

## Features

### System Characteristics
- **Minimal installation**: 3MB kernel binary
- **Performance optimized**: Native CPU optimizations, LTO, PGO
- **Bcachefs integration**: Multi-device filesystem with automatic tiering
- **Rolling release**: Latest packages via ~amd64 keywords
- **No display manager**: Direct TTY to Hyprland startup
- **efistub boot**: No traditional bootloader required

### Desktop Environment
- **Wayland compositor**: Hyprland with NVIDIA optimizations
- **Terminal**: kitty
- **Launcher**: wofi
- **Notifications**: dunst
- **Image viewer**: imv
- **Wallpaper**: hyprpaper
- **Clipboard**: wl-clipboard
- **Portals**: xdg-desktop-portal-hyprland

### Security and Privacy
- **doas instead of sudo**: Minimal privilege escalation
- **System-wide ad blocking**: StevenBlack hosts integration
- **Minimal attack surface**: Disabled unnecessary services and documentation

## Support Notes

This guide represents a specific configuration tested with the described hardware setup. Adaptations may be required for:
- AMD processors (microcode and kernel options)
- Different GPU configurations
- Alternative storage layouts
- Different bcachefs array configurations

The bcachefs integration extends the original Hyprland NVIDIA guide while preserving its minimal philosophy and efistub boot method.