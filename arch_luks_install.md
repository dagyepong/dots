# [Arch linux](https://archlinux.org) [installation](#1) [encrypted](#2) [btrfs](#3) [uki](#4) [systemd-boot](#5) [secure boot](#6) [tpm](#7)
Boot from a valid [Arch ISO](https://wiki.archlinux.org/title/Installation_guide#Acquire_an_installation_image), configure the [network](https://wiki.archlinux.org/title/Installation_guide#Connect_to_the_internet), and set up [SSH](https://wiki.archlinux.org/title/Install_Arch_Linux_via_SSH) if possible.
### Set up your UEFI Standard partition layout
```bash
cfdisk /dev/nvme0n1
Device          Start       End         Sectors    Size   Type
/dev/nvme0n1p1  882423808   884520959   2097152    1G     EFI System
/dev/nvme0n1p2  34816       629198847   629164032  300G   Linux filesystem
```
#### Encrypt your block device for root filesystem{#2}
```bash
cryptsetup luksFormat --type luks2 --cipher aes-xts-plain64 --key-size 512 --pbkdf argon2id --pbkdf-memory 1048576 --iter-time 4000 /dev/nvme0n1p2

cryptsetup open /dev/nvme0n1p2 root
```
#### Create filesystems{#3}
```bash
mkfs.vfat -n ArchBoot -F 32 /dev/nvme0n1p1
mkfs.btrfs -L ArchRoot /dev/mapper/root
```
#### Setup Mounts
```bash
mount LABEL=ArchRoot /mnt

# Create btrfs subvolumes accordingly your needs
btrfs su cr /mnt/{@,@home,@.snapshots,@opt,@srv,@db,@log,@tmp,@crash,@spool,@systemd,@NetworkManager,@pkg,@boot}

umount -l /mnt

mount -o subvol=@ LABEL=ArchRoot /mnt/

mkdir -p /mnt/{home,.snapshots,opt,srv,boot,efi,var/{db,log,tmp,crash,spool,lib/{systemd,NetworkManager},cache/pacman/pkg}}

mount -o subvol=@home LABEL=ArchRoot /mnt/home
mount -o subvol=@.snapshots LABEL=ArchRoot /mnt/.snapshots
mount -o subvol=@opt LABEL=ArchRoot /mnt/opt
mount -o subvol=@srv LABEL=ArchRoot /mnt/srv
mount -o subvol=@db LABEL=ArchRoot /mnt/var/db
mount -o subvol=@log LABEL=ArchRoot /mnt/var/log
mount -o subvol=@tmp LABEL=ArchRoot /mnt/var/tmp
mount -o subvol=@crash LABEL=ArchRoot /mnt/var/crash
mount -o subvol=@spool LABEL=ArchRoot /mnt/var/spool
mount -o subvol=@systemd LABEL=ArchRoot /mnt/var/lib/systemd
mount -o subvol=@NetworkManager LABEL=ArchRoot /mnt/var/lib/NetworkManager
mount -o subvol=@pkg LABEL=ArchRoot /mnt/var/cache/pacman/pkg
mount -o subvol=@boot LABEL=ArchRoot /mnt/boot
mount LABEL=ArchBoot /mnt/efi
```
#### Set default btrfs subvolume
```bash
btrfs inspect-internal rootid /mnt
btrfs subvolume set-default 256 /mnt
```
#### Install the base system with some necessary packages{#1}

```bash
pacstrap -K /mnt base linux linux-firmware linux-headers mkinitcpio cryptsetup btrfs-progs sbctl sudo nano networkmanager
```
### Entering chroot env
```bash
arch-chroot /mnt
```
#### Set up localizations
`nano /etc/locale.gen`
```bash
en_GB.UTF-8 UTF-8
```
```bash
locale-gen

echo LANG=en_GB.UTF-8 > /etc/locale.conf

ln -sf /usr/share/zoneinfo/YourRegion/City /etc/localtime

timedatectl set-local-rtc 1 ; timedatectl set-ntp true

echo Arch > /etc/hostname
```
#### Add sudo privileged user account
```bash
useradd -m -s /bin/bash -G audio,video username
passwd username

EDITOR=nano visudo
username ALL=(ALL) ALL
```
#### Add fstab mounts
`nano /etc/fstab`
```bash
LABEL=ArchRoot / btrfs rw,nodev,noatime,lazytime,skip_balance,nodatacow,ssd,discard,space_cache=v2,commit=120,subvol=/@ 0 0
LABEL=ArchRoot /home btrfs rw,nodev,noatime,lazytime,skip_balance,nodatacow,ssd,discard,space_cache=v2,commit=120,subvol=/@home 0 0
LABEL=ArchRoot /.snapshots btrfs rw,nodev,noatime,lazytime,skip_balance,nodatacow,ssd,discard,space_cache=v2,commit=120,subvol=/@.snapshots	0 0
LABEL=ArchRoot /opt btrfs rw,nodev,noatime,lazytime,skip_balance,nodatacow,ssd,discard,space_cache=v2,commit=120,subvol=/@opt 0 0
LABEL=ArchRoot /srv btrfs rw,nodev,noatime,lazytime,skip_balance,nodatacow,ssd,discard,space_cache=v2,commit=120,subvol=/@srv 0 0
LABEL=ArchRoot /var/db btrfs rw,nosuid,nodev,noexec,noatime,lazytime,skip_balance,ssd,discard,space_cache=v2,compress-force=zstd:10,commit=120,subvol=/@db	0 0
LABEL=ArchRoot /var/log btrfs rw,nosuid,nodev,noexec,noatime,lazytime,skip_balance,nodatacow,ssd,discard,space_cache=v2,commit=120,subvol=/@log	0 0
LABEL=ArchRoot /var/tmp btrfs rw,nosuid,nodev,noexec,noatime,lazytime,skip_balance,nodatacow,ssd,discard,space_cache=v2,commit=120,subvol=/@tmp	0 0
LABEL=ArchRoot /var/crash btrfs rw,nosuid,nodev,noexec,noatime,lazytime,skip_balance,nodatacow,ssd,discard,space_cache=v2,commit=120,subvol=/@crash	0 0
LABEL=ArchRoot /var/spool btrfs rw,nodev,noatime,lazytime,skip_balance,nodatacow,ssd,discard,space_cache=v2,commit=120,subvol=/@spool 0 0
LABEL=ArchRoot /var/lib/systemd btrfs rw,nodev,noatime,lazytime,skip_balance,nodatacow,ssd,discard,space_cache=v2,commit=120,subvol=/@systemd 0 0
LABEL=ArchRoot /var/lib/NetworkManager btrfs rw,nodev,noatime,lazytime,skip_balance,nodatacow,ssd,discard,space_cache=v2,commit=120,subvol=/@NetworkManager 0 0
LABEL=ArchRoot /var/cache/pacman/pkg btrfs rw,nosuid,nodev,noexec,noatime,lazytime,skip_balance,ssd,discard,space_cache=v2,compress-force=zstd:10,commit=120,subvol=/@pkg 0 0
LABEL=ArchRoot /boot btrfs rw,nosuid,nodev,noexec,noatime,lazytime,skip_balance,nodatacow,ssd,discard,space_cache=v2,commit=120,subvol=/@boot 0 0
LABEL=ArchBoot /efi vfat rw,nosuid,nodev,noexec,relatime,fmask=0077,dmask=0077,codepage=437,iocharset=ascii,shortname=mixed,utf8,discard,flush,errors=remount-ro	0 2
```
#### Configure mkinitcpio for UKI{#4}
`nano /etc/mkinitcpio.conf`
```bash
MODULES=(nvme)    # Add your hardware related modules here
# Change existing hooks to systemd-based
HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-encrypt block filesystems fsck)
```
`nano /etc/mkinitcpio.d/linux.preset`
```bash
ALL_kver="/boot/vmlinuz-linux"
PRESETS=('default')

default_uki="/efi/EFI/Boot/BOOTX64.efi"  # Set a bootable path and rename the UKI for direct boot
default_uki="/efi/EFI/Linux/arch-linux.efi"  # For systemd-boot, use the default

default_options="--splash /usr/share/systemd/bootctl/splash-arch.bmp"
```
#### Set kernel parameters
Add the UUID to the kernel command line
```bash
blkid /dev/nvme0n1p2
```
`nano /etc/kernel/cmdline`
```bash
rd.luks.name=<UUID FOR nvme0n1p2>=root root=LABEL=ArchRoot rootfstype=btrfs rootflags=subvol=@
```
#### Generate UKI
Create a directory based on your UKI path
```bash
mkdir -p /efi/EFI/Boot
mkdir -p /efi/EFI/Linux

# Now generate the UKI
mkinitcpio -P
```
If you’ve set a bootable UKI path, you can now `reboot` from here
#### Systemd boot{#5}
```bash
bootctl install
```
`nano /efi/loader/loader.conf`
```bash
default @saved
timeout  3
console-mode max
```
#### Finalize and reboot
```bash
exit
reboot
```
#### Enabling Secure Boot{#6}
Backup your current Secure Boot variables if important, and then process with the sbctl
```bash
# Configure Secure Boot to setup mode in your UEFI settings
sbctl status
sbctl create-keys
sbctl enroll-keys -m  # Exclude -m if you are not a Windows user
sbctl verify  # Check for unsigned files

# Now sign those file(s)
sbctl sign -s /efi/EFI/Boot/BOOTX64.efi
sbctl sign -s /efi/EFI/Linux/arch-linux.efi
sbctl sign -s /efi/EFI/systemd/systemd-bootx64.efi
sbctl sign -s -o /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed /usr/lib/systemd/boot/efi/systemd-bootx64.efi
```
#### Configure TPM2 for LUKS2 unlocking{#7}
Ensure your secureboot is enabled
```bash
systemd-cryptenroll /dev/nvme0n1p2 --recovery-key
systemd-cryptenroll /dev/nvme0n1p2 --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=0+7
```
---
#### If you experience any issues during installation, please follow the official Arch Linux [Installation guide](https://wiki.archlinux.org/title/Installation_guide). I used references from [ArchWiki](https://wiki.archlinux.org) and [Gentoo Wiki](https://wiki.gentoo.org) with some minor tweaks myself. I hope you find something helpful.