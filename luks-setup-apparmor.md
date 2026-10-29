Gentoo Linux Fully Automated EFISTUB Installation Guide
Encrypted Btrfs | OpenRC | Native EFI Boot | Secure Boot | TPM2 | AppArmor

This guide outlines the complete process for installing Gentoo Linux utilizing native EFISTUB booting, an encrypted Btrfs subvolume layout, OpenRC system initialization, AppArmor Mandatory Access Control, Secure Boot signing, and automated TPM2 unlocking via Clevis.

1. Disk Partitioning & Encryption
Set up your UEFI standard partition layout

Initialize your storage drive partitioning scheme:

```bash
cfdisk /dev/nvme0n1
```

Create a layout matching the following partition map:

    /dev/nvme0n1p1: 1G size, type EFI System

    /dev/nvme0n1p2: Remaining space, type Linux filesystem

Encrypt the root partition

Format your primary system block layer using LUKS2 encryption parameters:
```bash
cryptsetup luksFormat --type luks2 --cipher aes-xts-plain64 --key-size 512 --pbkdf argon2id --pbkdf-memory 1048576 --iter-time 4000 --label "GentooLuks" /dev/nvme0n1p2

cryptsetup open /dev/nvme0n1p2 root
```
Create filesystems

Initialize filesystems on the newly created partitions:
```bash
mkfs.vfat -n GentooBoot -F 32 /dev/nvme0n1p1
mkfs.btrfs -L GentooRoot /dev/mapper/root
```

2. Btrfs Subvolumes & Mounts

Mount the root file layer and create targeted Btrfs subvolumes to safely separate system states:
```bash
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
```

3. Stage3 Unpacking & Portage Configuration
```bash
cd /mnt/gentoo
# Download your preferred OpenRC stage3 archive (Hardened recommended)
wget https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-hardened-openrc/stage3-amd64-hardened-openrc-latest.tar.xz

# Extract stage image with extended attributes intact
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner -C /mnt/gentoo
```

Configure make.conf

Modify compilation profiles, features, and binary execution structures, including global apparmor support:
```bash
COMMON_FLAGS="-march=native -O2 -pipe"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
FCFLAGS="${COMMON_FLAGS}"
FFLAGS="${COMMON_FLAGS}"

LC_MESSAGES=C.UTF-8
ACCEPT_LICENSE="*"
USE="dist-kernel apparmor"

FEATURES="${FEATURES} getbinpkg binpkg-request-signature"
```
Copy live environment DNS resolution attributes
```bash
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/
```
4. Entering the Chroot

Bind virtual filesystems and establish the chroot containment execution environment:
```bash
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
```
5. System Configuration & Package Initialization
```bash
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
```
Install essential system and security utilities
```bash
emerge --ask app-editors/nano net-misc/networkmanager sys-fs/btrfs-progs sys-fs/cryptsetup sys-kernel/linux-firmware sys-firmware/sof-firmware sys-apps/apparmor sec-policy/apparmor-profiles
```
Set up Localizations & Timezone
```bash
nano /etc/locale.gen
```
Uncomment or add:
```bash
en_US.UTF-8 UTF-8

locale-gen
eselect locale set en_US.utf8

# Set timezone (Adjust America/New_York to your regional path)
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
```
6. Kernel & Bootloader Setup
Set up Package Flags

    [!IMPORTANT]
    We explicitly avoid enabling the uki flag on installkernel. This prevents conflicting execution pathways, ensuring that standard EFISTUB file patterns are compiled directly for native parsing by uefi-mkconfig.
```bash
mkdir -p /etc/portage/package.use
echo "sys-kernel/installkernel dracut efistub -uki -systemd" > /etc/portage/package.use/installkernel
echo "sys-apps/systemd-utils boot kernel-install" >> /etc/portage/package.use/systemd-utils

# Unmask modern boot utilities
mkdir -p /etc/portage/package.accept_keywords
echo "sys-kernel/installkernel" >> /etc/portage/package.accept_keywords/installkernel
echo "sys-boot/uefi-mkconfig" >> /etc/portage/package.accept_keywords/installkernel
```
Build or recompile boot hooks using the designated flags:
```bash
emerge --oneshot sys-apps/systemd-utils sys-kernel/installkernel sys-boot/uefi-mkconfig sys-fs/btrfs-progs sys-fs/cryptsetup
```
Configure Dracut for Encrypted Btrfs Storage

Hardcode the target encryption, device-mapper, and security modules to ensure AppArmor and encryption states load immediately upon boot:
```bash
nano /etc/dracut.conf



# PUT YOUR CONFIG IN separate files
# in /etc/dracut.conf.d named "<name>.conf"
# SEE man dracut.conf(5) for options
hostonly="no"
add_dracutmodules+=" crypt btrfs dm "
add_drivers+=" dm_crypt encrypted nvme ahci btrfs "
force_drivers+=" dm_crypt btrfs "
```
Install the Distribution Kernel
```bash
emerge --ask sys-kernel/gentoo-kernel
```
Prepare EFI target structural paths
```bash
mkdir -p /efi/EFI/Linux
mkdir -p /efi/EFI/Gentoo
```

Configure uefi-mkconfig Parameters

Obtain block information via blkid. Map the raw crypto_LUKS UUID container partition (/dev/nvme0n1p2) and the internal decoupled Btrfs root subvolume UUID. Ensure apparmor is included in the Linux Security Module (lsm=) parameter string.
```bash
nano /etc/default/uefi-mkconfig



Map your structural storage device specifications explicitly (replace UUIDs with your actual device values):


KERNEL_CONFIG="%entry_id %linux_name Linux %kernel_version ; rd.luks.uuid=f0f2e57d-b3dd-44fb-bf19-5875a82287ee root=UUID=79a2d19f-d489-4517-b8fb-cf3eb55b345a rootfstype=btrfs rootflags=subvol=@ lsm=landlock,lockdown,yama,integrity,apparmor,bpf"
```
Compile NVRAM motherboard execution items:
```bash
uefi-mkconfig -f
```

7. Base System Configurations
Configure filesystem mounts

Define persistent storage mounts within your environment configuration table:
```bash
nano /etc/fstab
```

```bash
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
```

Setup Core Environments & Services:

```bash
# Set Root Password
passwd root

# Create User Account
useradd -m -s /bin/bash -G audio,video,wheel username
passwd username

# Configure sudo permissions
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers.d/wheel

# System Name Definition
echo "gentoo" > /etc/hostname

# Enable System Networking and AppArmor Services on startup (OpenRC)
rc-update add NetworkManager default
rc-update add apparmor boot
```




##Limine Bootloader##

6. Stage 6: Bootloader & Kernel Adaptation (Using Limine instead of EFISTUB/uefi-mkconfig)

Instead of the uefi-mkconfig steps in your guide, execute these adapted commands inside your chroot:

    Adjust Portage package flags for installkernel:

```bash

mkdir -p /etc/portage/package.use
echo "sys-kernel/installkernel dracut -uki -systemd" > /etc/portage/package.use/installkernel
echo "sys-boot/limine" >> /etc/portage/package.use/installkernel

mkdir -p /etc/portage/package.accept_keywords
echo "sys-boot/limine" >> /etc/portage/package.accept_keywords/limine
```

Install Limine and core system utilities:

```bash
emerge --ask sys-boot/limine sys-kernel/installkernel sys-fs/btrfs-progs sys-fs/cryptsetup
```

Install Limine to your EFI partition:

```bash
mkdir -p /efi/EFI/Gentoo
cp /usr/share/limine/BOOTX64.EFI /efi/EFI/Gentoo/limine.efi
```
Create your limine.cfg on the EFI partition:
```bash
nano /efi/limine.cfg
```

(Paste your configuration using your actual LUKS and Btrfs UUIDs obtained via blkid):

```bash
TIMEOUT=3

/Gentoo Linux
    PROTOCOL=linux
    KERNEL_PATH=boot:///vmlinuz
    MODULE_PATH=boot:///initrd
    CMDLINE=rd.luks.uuid=YOUR_LUKS_UUID root=UUID=YOUR_BTRFS_UUID rootfstype=btrfs rootflags=subvol=@ lsm=landlock,lockdown,yama,integrity,apparmor,bpf
```

Set up the automation script so kernel upgrades update Limine automatically:

```bash
mkdir -p /etc/kernel/install.d
nano /etc/kernel/install.d/99-limine.install
```

(Paste this automation hook):

```bash
#!/bin/bash
COMMAND="$1"
KERNEL_VERSION="$2"
BOOT_DIR="$3"
KERNEL_IMAGE="$4"
EFI_BOOT="/efi"

case "$COMMAND" in
    add)
        cp "${KERNEL_IMAGE}" "${EFI_BOOT}/vmlinuz"
        if [ -f "${BOOT_DIR}/initrd" ]; then
            cp "${BOOT_DIR}/initrd" "${EFI_BOOT}/initrd"
        elif [ -f "${BOOT_DIR}/initramfs-${KERNEL_VERSION}.img" ]; then
            cp "${BOOT_DIR}/initramfs-${KERNEL_VERSION}.img" "${EFI_BOOT}/initrd"
        fi
        echo "Limine files updated for kernel ${KERNEL_VERSION}"
        ;;
    remove)
        rm -f "${EFI_BOOT}/vmlinuz" "${EFI_BOOT}/initrd"
        echo "Limine kernel files removed."
        ;;
esac
```

Make it executable:
```bash
chmod +x /etc/kernel/install.d/99-limine.install
```

Configure Dracut (/etc/dracut.conf.d/gentoo.conf):

```bash
mkdir -p /etc/dracut.conf.d
nano /etc/dracut.conf.d/gentoo.conf
```
```bash
hostonly="no"
add_dracutmodules+=" crypt btrfs dm "
add_drivers+=" dm_crypt encrypted nvme ahci btrfs "
force_drivers+=" dm_crypt btrfs "
```

Register Limine in your motherboard's NVRAM:

```bash
emerge --ask sys-boot/efibootmgr
```


```bash
efibootmgr --create --disk /dev/nvme0n1 --part 1 --label "Gentoo Limine" --loader /EFI/Gentoo/limine.efi
```

You should use --disk /dev/nvme0n1 --part 1.

Here is why:

    --disk /dev/nvme0n1 specifies the whole physical drive where your partition lives.

    --part 1 specifies partition number 1 on that drive (which corresponds to your /dev/nvme0n1p1 EFI partition).

efibootmgr expects the whole disk name for the --disk flag, and uses the separate --part flag to point to partition 1. So keeping it as --disk /dev/nvme0n1 --part 1 is precisely how it is supposed to be written!


The Final Step: Now, emerge your kernel:
```bash
emerge --ask sys-kernel/linux-firmware  sys-firmware/sof-firmware
```


