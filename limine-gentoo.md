Gentoo Linux Fully Automated Installation Guide
Encrypted Btrfs | OpenRC | Secure Boot Ready | AppArmor

1. Disk Partitioning & Encryption
Partition the Disk
Launch cfdisk on your target storage drive:

```bash
cfdisk /dev/nvme0n1
```

Create the following layout:

/dev/nvme0n1p1: 1G size, Type: EFI System

/dev/nvme0n1p2: Remaining Space, Type: Linux filesystem

Encrypt & Format
Format the root partition using LUKS2 and open the mapped volume:

```bash
cryptsetup luksFormat --type luks2 --cipher aes-xts-plain64 --key-size 512 --pbkdf argon2id --pbkdf-memory 1048576 --iter-time 4000 --label "GentooLuks" /dev/nvme0n1p2
cryptsetup open /dev/nvme0n1p2 root
```

Initialize filesystems:

```bash
mkfs.vfat -n GentooBoot -F 32 /dev/nvme0n1p1
mkfs.btrfs -L GentooRoot /dev/mapper/root
```

2. Btrfs Subvolume Layout & Mounting

```bash
mkdir -p /mnt/gentoo
mount LABEL=GentooRoot /mnt/gentoo/

# Create Btrfs subvolumes
btrfs su cr /mnt/gentoo/@
btrfs su cr /mnt/gentoo/@home
btrfs su cr /mnt/gentoo/@.snapshots
btrfs su cr /mnt/gentoo/@usr
btrfs su cr /mnt/gentoo/@opt
btrfs su cr /mnt/gentoo/@srv
btrfs su cr /mnt/gentoo/@db
btrfs su cr /mnt/gentoo/@log
btrfs su cr /mnt/gentoo/@tmp
btrfs su cr /mnt/gentoo/@crash
btrfs su cr /mnt/gentoo/@spool
btrfs su cr /mnt/gentoo/@portage
btrfs su cr /mnt/gentoo/@NetworkManager
btrfs su cr /mnt/gentoo/@binpkgs
btrfs su cr /mnt/gentoo/@distfiles
btrfs su cr /mnt/gentoo/@boot

umount -l /mnt/gentoo

# Mount root subvolume
mount -o subvol=@ LABEL=GentooRoot /mnt/gentoo

# Create target mount points
mkdir -p /mnt/gentoo/{home,.snapshots,usr,opt,srv,boot,efi,var/{db,log,tmp,crash,spool,lib/{portage,NetworkManager},cache/{binpkgs,distfiles}}}

# Mount subvolumes
mount -o subvol=@home LABEL=GentooRoot /mnt/gentoo/home
mount -o subvol=@.snapshots LABEL=GentooRoot /mnt/gentoo/.snapshots
mount -o subvol=@usr LABEL=GentooRoot /mnt/gentoo/usr
mount -o subvol=@opt LABEL=GentooRoot /mnt/gentoo/opt
mount -o subvol=@srv LABEL=GentooRoot /mnt/gentoo/srv
mount -o subvol=@db LABEL=GentooRoot /mnt/gentoo/var/db
mount -o subvol=@log LABEL=GentooRoot /mnt/gentoo/var/log
mount -o subvol=@tmp LABEL=GentooRoot /mnt/gentoo/var/tmp
mount -o subvol=@crash LABEL=GentooRoot /mnt/gentoo/var/crash
mount -o subvol=@spool LABEL=GentooRoot /mnt/gentoo/var/spool
mount -o subvol=@portage LABEL=GentooRoot /mnt/gentoo/var/lib/portage
mount -o subvol=@NetworkManager LABEL=GentooRoot /mnt/gentoo/var/lib/NetworkManager
mount -o subvol=@binpkgs LABEL=GentooRoot /mnt/gentoo/var/cache/binpkgs
mount -o subvol=@distfiles LABEL=GentooRoot /mnt/gentoo/var/cache/distfiles
mount -o subvol=@boot LABEL=GentooRoot /mnt/gentoo/boot

# Mount EFI System Partition
mount LABEL=GentooBoot /mnt/gentoo/efi
```

3. Stage3 Unpacking & Portage Setup

```bash
cd /mnt/gentoo
wget https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-hardened-openrc/stage3-amd64-hardened-openrc-latest.tar.xz
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner -C /mnt/gentoo
```

Configure /etc/portage/make.conf:

```bash
cat << 'EOF' > /mnt/gentoo/etc/portage/make.conf
COMMON_FLAGS="-march=native -O2 -pipe"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
FCFLAGS="${COMMON_FLAGS}"
FFLAGS="${COMMON_FLAGS}"

LC_MESSAGES=C.UTF-8
ACCEPT_LICENSE="*"
USE="dist-kernel apparmor"

FEATURES="${FEATURES} getbinpkg binpkg-request-signature"
EOF

cp --dereference /etc/resolv.conf /mnt/gentoo/etc/
```
4. Chroot Environment & Base System

```bash
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
mount --make-slave /mnt/gentoo/run

chroot /mnt/gentoo /bin/bash << 'CHROOT_ENV'
source /etc/profile
export PS1="(chroot) ${PS1}"

# Sync portage & profile configuration
emerge-webrsync
getuto
eselect profile set default/linux/amd64/23.0/hardened

# Optimize CPU flags
emerge --ask=n --oneshot app-portage/cpuid2cpuflags
echo "*/* $(cpuid2cpuflags)" > /etc/portage/package.use/00cpu-flags

# Update base system
emerge -uDUg @world
emerge --depclean

# Base system tools
emerge --ask=n app-editors/nano net-misc/networkmanager sys-fs/btrfs-progs sys-fs/cryptsetup sys-kernel/linux-firmware sys-firmware/sof-firmware sys-apps/apparmor sec-policy/apparmor-profiles

# Locale & Timezone
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
eselect locale set en_US.utf8
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
CHROOT_ENV
```

5. Dracut Initramfs Configuration
Inside the chroot, configure Dracut modules for encrypted Btrfs support:

```bash
mkdir -p /mnt/gentoo/etc/dracut.conf.d
cat << 'EOF' > /mnt/gentoo/etc/dracut.conf.d/gentoo.conf
hostonly="no"
add_dracutmodules+=" crypt btrfs dm "
add_drivers+=" dm_crypt encrypted nvme ahci btrfs "
force_drivers+=" dm_crypt btrfs "
EOF
```

6. Bootloader & Kernel OptionsChoose either Option A or Option B below to complete your system installation.OPTION A: Native EFISTUB Bootloader (via uefi-mkconfig)This script installs gentoo-kernel and registers EFISTUB entries directly into your NVRAM motherboard boot menu using uefi-mkconfig.1.Execute EFISTUB Installation Script:Option A Setup.Run the following block inside your chroot environment:

```bash
# 1. Configure Portage Use Flags for EFISTUB
mkdir -p /etc/portage/package.use /etc/portage/package.accept_keywords
echo "sys-kernel/installkernel dracut efistub -uki -systemd" > /etc/portage/package.use/installkernel
echo "sys-apps/systemd-utils boot kernel-install" >> /etc/portage/package.use/systemd-utils
echo "sys-kernel/installkernel" >> /etc/portage/package.accept_keywords/installkernel
echo "sys-boot/uefi-mkconfig" >> /etc/portage/package.accept_keywords/installkernel

# 2. Build boot tools
emerge --oneshot sys-apps/systemd-utils sys-kernel/installkernel sys-boot/uefi-mkconfig sys-fs/btrfs-progs sys-fs/cryptsetup

# 3. Create EFI directories
mkdir -p /efi/EFI/Linux /efi/EFI/Gentoo

# 4. Get UUIDs dynamically
RAW_LUKS_UUID=$(blkid -s UUID -o value /dev/nvme0n1p2)
ROOT_FS_UUID=$(blkid -s UUID -o value /dev/mapper/root)

# 5. Configure uefi-mkconfig
cat << EOF > /etc/default/uefi-mkconfig
KERNEL_CONFIG="%entry_id %linux_name Linux %kernel_version ; rd.luks.uuid=${RAW_LUKS_UUID} root=UUID=${ROOT_FS_UUID} rootfstype=btrfs rootflags=subvol=@ lsm=landlock,lockdown,yama,integrity,apparmor,bpf"
EOF

# 6. Install Kernel & Build NVRAM Entries
emerge --ask=n sys-kernel/gentoo-kernel
uefi-mkconfig -f
```

OPTION B: Limine Bootloader ImplementationThis script installs Limine, places executable components in /efi/EFI/Gentoo/, creates the dynamic installation hook (99-limine.install), and configures NVRAM boot entries.1.Execute Limine Bootloader Script:Option B Setup.Run the following block inside your chroot environment:

```bash
# 1. Configure Portage Use Flags for Limine
mkdir -p /etc/portage/package.use /etc/portage/package.accept_keywords
echo "sys-kernel/installkernel dracut -uki -systemd" > /etc/portage/package.use/installkernel
echo "sys-boot/limine" >> /etc/portage/package.use/installkernel
echo "sys-boot/limine" >> /etc/portage/package.accept_keywords/limine
echo "sys-boot/efibootmgr" >> /etc/portage/package.accept_keywords/efibootmgr

# 2. Emerge Limine and utilities
emerge --oneshot sys-boot/limine sys-kernel/installkernel sys-fs/btrfs-progs sys-fs/cryptsetup sys-boot/efibootmgr

# 3. Install Limine EFI Binary
mkdir -p /efi/EFI/Gentoo
cp /usr/share/limine/BOOTX64.EFI /efi/EFI/Gentoo/limine.efi

# 4. Get UUIDs dynamically
RAW_LUKS_UUID=$(blkid -s UUID -o value /dev/nvme0n1p2)
ROOT_FS_UUID=$(blkid -s UUID -o value /dev/mapper/root)

# 5. Create limine.conf pointing to /EFI/Gentoo/ relative paths
cat << EOF > /efi/EFI/Gentoo/limine.conf
timeout: 3

/Gentoo Linux
    protocol: linux
    kernel_path: boot():/EFI/Gentoo/vmlinuz
    module_path: boot():/EFI/Gentoo/initrd
    cmdline: rd.luks.uuid=${RAW_LUKS_UUID} root=UUID=${ROOT_FS_UUID} rootfstype=btrfs rootflags=subvol=@ lsm=landlock,lockdown,yama,integrity,apparmor,bpf
EOF

# 6. Create Automation Hook for Limine Kernel Updates
mkdir -p /etc/kernel/install.d
cat << 'EOF' > /etc/kernel/install.d/99-limine.install
#!/bin/bash
COMMAND="$1"
KERNEL_VERSION="$2"
BOOT_DIR="$3"
KERNEL_IMAGE="$4"
EFI_BOOT="/efi/EFI/Gentoo"

mkdir -p "${EFI_BOOT}"

case "$COMMAND" in
    add)
        cp "${KERNEL_IMAGE}" "${EFI_BOOT}/vmlinuz"
        if [ -f "${BOOT_DIR}/initrd" ]; then
            cp "${BOOT_DIR}/initrd" "${EFI_BOOT}/initrd"
        elif [ -f "${BOOT_DIR}/initramfs-${KERNEL_VERSION}.img" ]; then
            cp "${BOOT_DIR}/initramfs-${KERNEL_VERSION}.img" "${EFI_BOOT}/initrd"
        elif [ -f "${BOOT_DIR}/initramfs.img" ]; then
            cp "${BOOT_DIR}/initramfs.img" "${EFI_BOOT}/initrd"
        fi
        echo "Limine files updated for kernel ${KERNEL_VERSION}"
        ;;
    remove)
        rm -f "${EFI_BOOT}/vmlinuz" "${EFI_BOOT}/initrd"
        echo "Limine kernel files removed."
        ;;
esac
EOF

chmod +x /etc/kernel/install.d/99-limine.install

# 7. Register Limine in NVRAM
efibootmgr --create --disk /dev/nvme0n1 --part 1 --label "Gentoo Limine" --loader /EFI/Gentoo/limine.efi

# 8. Install Distribution Kernel (Triggers 99-limine.install automatically)
emerge --ask=n sys-kernel/gentoo-kernel
```

Verification: Verify that ls /efi/EFI/Gentoo/ contains limine.efi, limine.conf, vmlinuz, and initrd.

Manual Fix:
1.Check your /boot subvolume:2 min.Check what kernel and initramfs files are currently stored inside your /boot directory:

```bash
ls -l /boot/
```

1.Copy and rename kernel files:1 min.Copy the hardened kernel and initramfs files from /boot into your Limine EFI partition with the exact filenames expected by your config:

```bash
cp /boot/vmlinuz-7.3.1-gentoo-dist-hardened /efi/EFI/Gentoo/vmlinuz
cp /boot/initramfs-7.3.1-gentoo-dist-hardened.img /efi/EFI/Gentoo/initrd
```

Verification: Run ls -l /efi/EFI/Gentoo/ to confirm vmlinuz and initrd now appear alongside limine.conf and limine.efi.





7. System Finalization (Both Options)
Configure persistent mount points, root password, and system services:

```bash
# Configure fstab
cat << 'EOF' > /etc/fstab
LABEL=GentooRoot / btrfs rw,noatime,ssd,discard=async,space_cache=v2,subvol=/@ 0 0
LABEL=GentooRoot /home btrfs rw,noatime,ssd,discard=async,space_cache=v2,subvol=/@home 0 0
LABEL=GentooRoot /.snapshots btrfs rw,noatime,ssd,discard=async,space_cache=v2,subvol=/@.snapshots 0 0
LABEL=GentooRoot /usr btrfs rw,noatime,ssd,discard=async,space_cache=v2,subvol=/@usr 0 0
LABEL=GentooRoot /opt btrfs rw,noatime,ssd,discard=async,space_cache=v2,subvol=/@opt 0 0
LABEL=GentooRoot /srv btrfs rw,noatime,ssd,discard=async,space_cache=v2,subvol=/@srv 0 0
LABEL=GentooRoot /var/db btrfs rw,noatime,ssd,discard=async,space_cache=v2,subvol=/@db 0 0
LABEL=GentooRoot /var/log btrfs rw,noatime,ssd,discard=async,space_cache=v2,subvol=/@log 0 0
LABEL=GentooRoot /var/tmp btrfs rw,noatime,ssd,discard=async,space_cache=v2,subvol=/@tmp 0 0
LABEL=GentooRoot /var/crash btrfs rw,noatime,ssd,discard=async,space_cache=v2,subvol=/@crash 0 0
LABEL=GentooRoot /var/spool btrfs rw,noatime,ssd,discard=async,space_cache=v2,subvol=/@spool 0 0
LABEL=GentooRoot /var/lib/portage btrfs rw,noatime,ssd,discard=async,space_cache=v2,subvol=/@portage 0 0
LABEL=GentooRoot /var/lib/NetworkManager btrfs rw,noatime,ssd,discard=async,space_cache=v2,subvol=/@NetworkManager 0 0
LABEL=GentooRoot /var/cache/binpkgs btrfs rw,noatime,ssd,discard=async,space_cache=v2,compress-force=zstd:1,subvol=/@binpkgs 0 0
LABEL=GentooRoot /var/cache/distfiles btrfs rw,noatime,ssd,discard=async,space_cache=v2,compress-force=zstd:1,subvol=/@distfiles 0 0
LABEL=GentooRoot /boot btrfs rw,noatime,ssd,discard=async,space_cache=v2,subvol=/@boot 0 0
LABEL=GentooBoot /efi vfat rw,nosuid,nodev,noexec,fmask=0077,dmask=0077,utf8,discard 0 2
EOF

# User Accounts & Hostname
echo "gentoo" > /etc/hostname
rc-update add NetworkManager default
rc-update add apparmor boot

# Set Root Password & Add Standard User
echo "Set root password:"
passwd

useradd -m -s /bin/bash -G audio,video,wheel username
echo "Set password for username:"
passwd username
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers.d/wheel
```

Unmount & Reboot
Exit the chroot environment and unmount all target filesystems safely to avoid corrupting your newly written Btrfs metadata before rebooting:
exit && umount -R /mnt/gentoo && reboot




Setting up tuigreet (a terminal-based greeter for greetd) to launch the niri Wayland compositor requires configuring greetd to run tuigreet and passing the proper session launch command for niri. Because niri is a Wayland compositor, it requires environment variables and a session wrapper or direct command execution.

Here is the complete step-by-step guide to installing, configuring, and launching tuigreet with niri on an OpenRC system.

1. Install greetd, tuigreet, and niri
Inside your chroot or live environment, install the required packages:


```bash
emerge --ask sys-apps/greetd gui-apps/tuigreet 
```

```bash
rc-update add display-manager default
```

Configure greetd
greetd manages login sessions via its configuration file located at /etc/greetd/config.toml.

Create and configure the file:

```bash
mkdir -p /etc/greetd

cat << 'EOF' > /etc/greetd/config.toml
[terminal]
# The vt to run the greeter on
vt = 7

[default_session]
# Command to run tuigreet as the greeter
command = "tuigreet --time --remember --remember-user-session --sessions /usr/share/wayland-sessions:/usr/share/xsessions --asterisks"

# Run the greeter as the greetd user
user = "greetd"
EOF
```

Ensure Niri Session File Exists
Verify that a desktop session file exists for niri so tuigreet can automatically detect and launch it. Usually, gui-wm/niri installs this file automatically, but you can create it manually if it's missing:

```bash
mkdir -p /usr/share/wayland-sessions

cat << 'EOF' > /usr/share/wayland-sessions/niri.desktop
[Desktop Entry]
Name=Niri
Comment=A scrollable-tiling Wayland compositor
Exec=dbus-run-session niri --session
Type=Application
DesktopNames=niri
EOF
```
Also change display-manager conf:

```bash
 󱞩 sudo cat /etc/conf.d/display-manager 
Password: 
# We always try and start the DM on a static VT. The various DMs normally
# default to using VT7. If you wish to use the display-manager init
# script, then you should ensure that the VT checked is the same VT your
# DM wants to use.
# We do this check to ensure that you haven't accidentally configured
# something to run on the VT in your /etc/inittab file so that
# you don't get a dead keyboard.
# sddm ignores this env var and is configured at build-time to use VT7.
CHECKVT=7

# What display manager do you use ?
#     [ xdm | greetd | gdm | sddm | gpe | lightdm | entrance ]
# NOTE: If this is set in /etc/rc.conf, that setting will override this one.
DISPLAYMANAGER="greetd"
```

Restart service:

```bash
sudo rc-service  display-manager restart
```
