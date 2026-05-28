# Gentoo Linux Fully Automated EFISTUB Installation Guide
### Encrypted Btrfs | OpenRC | Native EFI Boot | Secure Boot | TPM2

This guide outlines the complete process for installing Gentoo Linux utilizing native EFISTUB booting, an encrypted Btrfs subvolume layout, OpenRC system initialization, Secure Boot signing, and automated TPM2 unlocking via Clevis.

---

## 1. Disk Partitioning & Encryption

### Set up your UEFI standard partition layout
Initialize your storage drive partitioning scheme:
```bash
cfdisk /dev/nvme0n1

Create a layout matching the following partition map:

    /dev/nvme0n1p1: 1G size, type EFI System

    /dev/nvme0n1p2: Remaining space, type Linux filesystem

Encrypt the root partition

Format your primary system block layer using LUKS2 encryption parameters:
Bash

cryptsetup luksFormat --type luks2 --cipher aes-xts-plain64 --key-size 512 --pbkdf argon2id --pbkdf-memory 1048576 --iter-time 4000 --label "GentooLuks" /dev/nvme0n1p2

cryptsetup open /dev/nvme0n1p2 root

Create filesystems

Initialize filesystems on the newly created partitions:
Bash

mkfs.vfat -n GentooBoot -F 32 /dev/nvme0n1p1
mkfs.btrfs -L GentooRoot /dev/mapper/root

2. Btrfs Subvolumes & Mounts

Mount the root file layer and create targeted Btrfs subvolumes to safely separate system states:
Bash

mkdir -p /mnt/gentoo
mount LABEL=GentooRoot /mnt/gentoo/

# Create btrfs subvolumes
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

# Create target system mountpoints
mkdir -p /mnt/gentoo/{home,.snapshots,usr,opt,srv,boot,efi,var/{db,log,tmp,crash,spool,lib/{portage,NetworkManager},cache/{binpkgs,distfiles}}}

# Mount remaining subvolumes
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

# Mount the EFI System Partition
mount LABEL=GentooBoot /mnt/gentoo/efi

3. Stage3 Unpacking & Portage Configuration
Bash

cd /mnt/gentoo
# Download your preferred OpenRC stage3 archive (Hardened recommended)
wget [https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-hardened-openrc/stage3-amd64-hardened-openrc-latest.tar.xz](https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-hardened-openrc/stage3-amd64-hardened-openrc-latest.tar.xz)

# Extract stage image with extended attributes intact
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner -C /mnt/gentoo

Configure make.conf

Modify compilation profiles, features, and binary execution structures:
nano /mnt/gentoo/etc/portage/make.conf
Plaintext

COMMON_FLAGS="-march=native -O2 -pipe"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
FCFLAGS="${COMMON_FLAGS}"
FFLAGS="${COMMON_FLAGS}"

LC_MESSAGES=C.UTF-8
ACCEPT_LICENSE="*"
USE="dist-kernel"

FEATURES="${FEATURES} getbinpkg binpkg-request-signature"

Copy live environment DNS resolution attributes prior to initializing the chroot:
Bash

cp --dereference /etc/resolv.conf /mnt/gentoo/etc/

4. Entering the Chroot

Bind virtual filesystems and establish the chroot containment execution environment:
Bash

mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
mount --make-slave /mnt/gentoo/run

chroot /mnt/gentoo /bin/bash
source /etc/profile
export PS1="(chroot) ${PS1}"

5. System Configuration & Package Initialization
Bash

# Sync repositories and set up binary package verification keys
emerge-webrsync
getuto

# Choose your profile (Example uses 23.0 Hardened OpenRC)
eselect profile set default/linux/amd64/23.0/hardened

# Optimize CPU flags globally
emerge --ask --oneshot app-portage/cpuid2cpuflags
echo "*/* $(cpuid2cpuflags)" > /etc/portage/package.use/00cpu-flags

# Update world set to match profile changes
emerge -avuDUg @world
emerge --ask --depclean

# Install essential system utilities
emerge --ask app-editors/nano net-misc/networkmanager sys-fs/btrfs-progs sys-fs/cryptsetup sys-kernel/linux-firmware sys-firmware/sof-firmware

Set up Localizations & Timezone

Define system generation locales:
nano /etc/locale.gen
Plaintext

en_US.UTF-8 UTF-8

Bash

locale-gen
eselect locale set en_US.utf8

# Set timezone (Adjust America/New_York to your regional path)
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime

6. Kernel & Bootloader Setup
Set up Package Flags

    [!IMPORTANT]

    We explicitly avoid enabling the uki flag on installkernel. This prevents conflicting execution pathways, ensuring that standard EFISTUB file patterns are compiled directly for native parsing by uefi-mkconfig.

Bash

mkdir -p /etc/portage/package.use
echo "sys-kernel/installkernel dracut efistub -uki -systemd" > /etc/portage/package.use/installkernel
echo "sys-apps/systemd-utils boot kernel-install" >> /etc/portage/package.use/systemd-utils

# Unmask modern boot utilities
mkdir -p /etc/portage/package.accept_keywords
echo "sys-kernel/installkernel" >> /etc/portage/package.accept_keywords/installkernel
echo "sys-boot/uefi-mkconfig" >> /etc/portage/package.accept_keywords/installkernel

Build or recompile boot hooks using the designated flags:
Bash

emerge --oneshot sys-apps/systemd-utils sys-kernel/installkernel sys-boot/uefi-mkconfig

Configure Dracut for Encrypted Btrfs Storage

Hardcode the target encryption and device-mapper modules to prevent minimal or stripped execution builds during future kernel updates.

nano /etc/dracut.conf
Plaintext

hostonly="no"
add_dracutmodules+=" crypt btrfs dm "
add_drivers+=" dm_crypt encrypted nvme ahci btrfs "
force_drivers+=" dm_crypt btrfs "

Install the Distribution Kernel
Bash

emerge --ask sys-kernel/gentoo-kernel-bin

Prepare EFI target structural paths
Bash

mkdir -p /efi/EFI/Linux
mkdir -p /efi/EFI/Gentoo

Configure uefi-mkconfig Parameters

Obtain block information via blkid. Map the raw crypto_LUKS UUID container partition (/dev/nvme0n1p2) and the internal decoupled Btrfs root subvolume UUID (/dev/mapper/root).

nano /etc/default/uefi-mkconfig
Plaintext

# Map your structural storage device specifications explicitly
KERNEL_CONFIG="%entry_id %linux_name Linux %kernel_version ; rd.luks.uuid=YOUR_LUKS_UUID root=UUID=YOUR_BTRFS_ROOT_UUID rootfstype=btrfs rootflags=subvol=@"

Compile NVRAM motherboard execution items:
Bash

uefi-mkconfig -f

7. Base System Configurations
Configure filesystem mounts

Define persistent storage mounts within your environment configuration table:
nano /etc/fstab
Plaintext

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

Install Essential Administration Tools
Bash

emerge --ask app-admin/sudo app-shells/bash-completion

Setup Core Environments
Bash

# Set Root Password
passwd root

# Create User Account
useradd -m -s /bin/bash -G audio,video,wheel username
passwd username

# Configure sudo permissions
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers.d/wheel

# System Name Definition
echo "gentoo" > /etc/hostname

# Enable System Networking Services on startup
rc-update add NetworkManager default

8. Secure Boot Signing & Automated Hook Installation
Bash

emerge --ask app-crypt/efitools app-crypt/sbsigntools dev-libs/openssl app-crypt/clevis

Generate Signature Infrastructure Keys
Bash

mkdir -p /etc/efikeys && cd /etc/efikeys
uuidgen --random > guid.txt

openssl req -new -x509 -newkey rsa:4096 -subj "/CN=My Platform Key/" -keyout pk.key -out pk.crt -days 3650 -nodes -sha512
openssl req -new -x509 -newkey rsa:4096 -subj "/CN=My Key Exchange Key/" -keyout kek.key -out kek.crt -days 3650 -nodes -sha512
openssl req -new -x509 -newkey rsa:4096 -subj "/CN=My Signature DB Key/" -keyout db.key -out db.crt -days 3650 -nodes -sha512

cert-to-efi-sig-list -g "$(< guid.txt)" pk.crt pk.esl
sign-efi-sig-list -k pk.key -c pk.crt PK pk.esl pk.auth
cert-to-efi-sig-list -g "$(< guid.txt)" kek.crt kek.esl
cert-to-efi-sig-list -g "$(< guid.txt)" db.crt db.esl

# Back up old firmwares and merge lists
efi-readvar -v KEK -o old_KEK.esl
efi-readvar -v db -o old_db.esl
cat old_KEK.esl kek.esl > combined_KEK.esl
cat old_db.esl db.esl > combined_db.esl

(Enroll your final signature packages—combined_KEK.esl, combined_db.esl, and pk.auth—manually inside your motherboard's native UEFI BIOS interface configuration menus).
Encrypt Key Records with TPM2 via Clevis
Bash

clevis encrypt tpm2 '{"pcr_bank":"sha256","pcr_ids":"0"}' < /etc/efikeys/db.key > /etc/efikeys/db.key.jwe

Set up automated image signing hooks

Establish a custom post-installation trigger phase. This automatically calls sbsign, intercepts updated execution targets inside Portage, and signs them safely using your TPM2-secured credentials.
Bash

mkdir -p /etc/portage/env/sys-kernel

nano /etc/portage/env/sys-kernel/gentoo-kernel-bin
Bash

pre_pkg_postinst() {
    local kernel_version="${PV}-${PR}"
    local target_efi="/efi/EFI/Linux/gentoo-${kernel_version}.efi"
    
    if [ -f "${target_efi}" ]; then
        einfo "Signing updated EFISTUB target executable: ${target_efi}"
        sbsign --key <(clevis decrypt < /etc/efikeys/db.key.jwe) \
               --cert /etc/efikeys/db.crt \
               --output "${target_efi}" "${target_efi}"
    fi
}

Bash

chmod +x /etc/portage/env/sys-kernel/gentoo-kernel-bin

9. Finalization and TPM LUKS Auto-Unlock

Trigger an explicit installation of your kernel package to fire off your automated crypt-signing module hooks:
Bash

emerge -1 gentoo-kernel-bin

Enable Automatic LUKS Decryption via TPM2

Bind your LUKS partition key slot to your motherboard's secure cryptographic module architecture:
Bash

clevis luks bind -d /dev/nvme0n1p2 tpm2 '{"pcr_bank":"sha256","pcr_ids":"0,7,9"}'

Regenerate kernel image files and update the NVRAM mapping strings one final time:
Bash

installkernel -a /lib/modules
uefi-mkconfig -f

Your system is now successfully built. Exit the active shell context, cleanly unmount your temporary system nodes, and restart your computer to enter your production-hardened environment.
