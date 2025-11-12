# Gentoo Install Guide

## Table of Contents
- [Gentoo Install Guide](#gentoo-install-guide)
  - [Table of Contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Create the bootable USB](#create-the-bootable-usb)
  - [Connect to the Network](#connect-to-the-network)
    - [Test the Network](#test-the-network)
    - [`dhcpcd` isn't running](#dhcpcd-isnt-running)
    - [Set Date and Time](#set-date-and-time)
  - [Disk Setup](#disk-setup)
    - [Partition with `fdisk`](#partition-with-fdisk)
    - [Create Filesystems](#create-filesystems)
      - [Create BTRFS subvolumes (optional)](#create-btrfs-subvolumes-optional)
  - [The Stage File](#the-stage-file)
    - [Set initial build flags](#set-initial-build-flags)
  - [Chroot](#chroot)
  - [Configure Portage](#configure-portage)
    - [Setup the Binary Package Host (optional)](#setup-the-binary-package-host-optional)
    - [VIDEO\_CARDS Flag](#video_cards-flag)
    - [Accept Optional Licenses](#accept-optional-licenses)
    - [Update @world (optional)](#update-world-optional)
  - [Set the Timezone](#set-the-timezone)
  - [Set the Locale](#set-the-locale)
  - [Install Firmware](#install-firmware)
  - [installkernel](#installkernel)
  - [Creating the fstab](#creating-the-fstab)
  - [Set up Networking](#set-up-networking)
  - [Systemd Configuration](#systemd-configuration)
  - [System Tools](#system-tools)
  - [Install GRUB](#install-grub)
  - [Rebooting the System](#rebooting-the-system)
  - [User Admin](#user-admin)
    - [Create a user account](#create-a-user-account)
    - [Install sudo](#install-sudo)
    - [Disable the root account](#disable-the-root-account)
  - [Install GNOME](#install-gnome)
  - [Flatpak](#flatpak)
    - [Install GNOME Software](#install-gnome-software)
  - [Change MAKEOPTS](#change-makeopts)
  - [Post Install](#post-install)
      - [Use newer kernels](#use-newer-kernels)
      - [Pipewire for audio](#pipewire-for-audio)
      - [X-Plane support](#x-plane-support)


## Introduction

This guide is based on the wiki but is simplified based on how I install Gentoo. This guide uses:
* an EFI system
* swap
* BTRFS (with subvolumes)
* GNOME (desktop profile)
* Dist kernel bin
* Systemd init

It is generally recommended to install the dist-kernel initially so you can boot into the system. A customized kernel can then
be built afterwards and the dist-kernel is kept as a fallback. This guide will use the precompiled bin kernel.

Also keep in mind my hardware may differ from yours:
* AMD 5700x
* 64gb RAM
* AMD 6800XT
* NVMe SSD

## Create the bootable USB
From a Linux system, run the commands:
```bash
# determine the target disk
lsblk

# write the ISO to the target disk
dd if=install-amd64-minimal-*.iso of=/dev/sdb bs=4096 status=progress && sync
```
Eject the USB and reboot the system from the USB. Ensure secure boot is turned OFF in the BIOS.

## Connect to the Network
`dhcpcd` should already be running.

### Test the Network
```bash
# Sends 3 pings to 1.1.1.1
ping -c 3 1.1.1.1
```
To test HTTPS:
```bash
# Sends HTTPS request to Gentoo.org and outputs to /dev/null (purges the output)
curl --location gentoo.org --output /dev/null
```
If the HTTPS request fails, the system time might need to be set.

### `dhcpcd` isn't running
Gentoo ISOs should boot with `dhcpcd` already running, but if it isn't:  
Determine the correct network interface link:
```bash
ip link
```
There should be at least two items returned by the command: `lo` (loopback) and `enp6s0` (ethernet adapter; the numbers might be
different).
Run the `dhcpcd` command with the ethernet adapter as an argument:
```bash
dhcpcd enp6s0
```

### Set Date and Time
```bash
# Determine current date and time according to the system
date
# Tue Dec  1 00:00:00 UTC 2024

# Automatically set the correct date/time:
chronyd -q

# Manually set the correct date/time (doesn't need to be exact, only close)
# MMDDhhmmYYYY MMonth DDate hhour mminute YYYYear
date 120319352024

# Verify
date
# Tue Dec  3 19:35:22 UTC 2024
```

## Disk Setup
This guide assumes you are using an EFI system with BTRFS, subvolumes, and swap. The swap portion is optional and is easily
omitted. This guide will also not make use of the Discoverable Partition Scheme.

| #   | Partition      | Filesystem | Size                | Description    |
| --- | ---            | ---        | ---                 | ---            |
| 1   | /dev/nvme0n1p1 | fat32      | 1GiB                | EFI Partition  |
| 2   | /dev/nvme0n1p2 | swap       | 8GiB                | Swap           |
| 3   | /dev/nvme0n1p3 | btrfs      | (remainder of disk) | Root partition |

8 GiB is a good size for a swap partition, but it varies based on system memory and whether you want hibernation support.
[See here for more.](https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Disks#What_about_swap_space.3F)

### Partition with `fdisk`
```bash
# Run fdisk on the target
fdisk /dev/nvme0n1

# Create a new GPT partition table
g

# Create the EFI system partition
n # new partition
  1 # partition 1, or press <enter>
  <enter> # first sector should be at the beginning of the disk by pressing enter
  +1G # set size to 1 GiB
  # Remove the fs signature if prompted.

t # set partition type
  # partition 1 should be automatically selected
  1 # partition type
  # Changed type of partition 'Linux filesystem' to 'EFI System'

# Create swap partition
n
  2 # or press <enter>
  <enter>
  +8G # 8GiB swap, yours may be different

t
  2
  19 # swap type
  # Changed type of partition 'Linux filesystem' to 'Linux swap'
  
# Create root partition
n
  3
  <enter>
  <enter> # rest of disk
  
t
  3
  23 # Linux root (x86-64)
  
# Verify the partition table is correct:
p

# Write the partition table
w
# fdisk should automatically exit now
```

### Create Filesystems
Check partition numbers:
```bash
lsblk
#~output:
nvme0n1
├─nvme0n1p1
├─nvme0n1p2
└─nvme0n1p3
```

First, create the EFI filesystem on `nvme0n1p1`:
```bash
mkfs.vfat -F 32 /dev/nvme0n1p1
```

Second, create the swap filesystem on `nvme0n1p2`:
```bash
mkswap /dev/nvme0n1p2
# activate the swap now
swapon /dev/nvme0n1p2
```

Third, create and mount the root filesystem on `nvme0n1p3`:
```bash
mkfs.btrfs /dev/nvme0n1p3

mkdir -p /mnt/gentoo

mount /dev/nvme0n1p3 /mnt/gentoo
```

#### Create BTRFS subvolumes (optional)
BTRFS has a handy feature called *snapshots*, which serve as a sort of local backup. They can really save your bacon after an update or if you accidentally delete something. Snapshots are taken of an entire subvolume, which is why subvolumes are used. Below is a subvolume layout of the root and home directories. You might also consider creating subvolumes for `@tmp`, `@log`, and `@snapshots`. Doing so ensures that those directories are not included when snapshotting the `@` subvolume. [Timeshift](https://github.com/linuxmint/timeshift) can be used for creating and managing snapshots, but must be built from source.
```bash
btrfs subvolume create /mnt/gentoo/@
btrfs subvolume create /mnt/gentoo/@home

# unmount /mnt/gentoo
umount /mnt/gentoo

# mount subvolumes (compression is optional)
mount -o compress=zstd,subvol=@ /dev/nvme0n1p3 /mnt/gentoo
mkdir -p /mnt/gentoo/home
mount -o compress=zstd,subvol=@home /dev/nvme0n1p3 /mnt/gentoo/home
```

Also create and mount the `efi` directory regardless of if you used subvolumes:
```bash
mkdir -p /mnt/gentoo/efi
mount /dev/nvme0n1p1 /mnt/gentoo/efi
```

## The Stage File
The stage file serves as the "jumping-off-point" for your Gentoo installation.

```bash
# set the current directory to the root of the install:
cd /mnt/gentoo
```

Head to [this link](https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-desktop-systemd/) to detmine the
URL to download the latest stage3 file. Do not download it from your web browser. Each file as a format like
`stage3-amd64-desktop-systemd-20241201T164824Z.tar.xz`. Take note of the timestamp: `20241201T164824Z`.

```bash
# Note the <TIMESTAMP> will need to be replaced with the current timestamp.
wget https://distfiles.gentoo.org/releases/amd64/autobuilds/<TIMESTAMP>/stage3-amd64-desktop-systemd-<TIMESTAMP>.tar.xz
```

The cryptographic signature of the downloaded file can be optionally checked (not covered here).

To extract the stage file:
```bash
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner -C /mnt/gentoo
```

### Set initial build flags
Use the editor of your choice to open `/mnt/gentoo/etc/portage/make.conf` and set the `march` (microarchitecture) flag to native:
```bash
COMMON_FLAGS="-march=native -O2 -pipe"
```

Optionally, you can limit the number of make jobs that run concurrently. By default this is simply the same number of threads
reported by your CPU (16 for 5700x). To speed up the install, the default is a good choice then it can be changed to a lower
number later (such as half the total threads):
```bash
# j is jobs
# l is load-average (default j+1)
MAKEOPTS="-j8 -l9"
```

## Chroot
Chroot is a process that tells our system to treat `/mnt/gentoo` as the root of the filesystem even though we haven't booted into
the system yet.

```bash
# First, copy the network DNS info (unable to connect to internet without this step)
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/

# Chroot into the system
arch-chroot /mnt/gentoo

# Optionally change the command prompt to remind us that we are in the chroot:
export PS1="(chroot) ${PS1}"
```

## Configure Portage
```bash
# Sync the ebuild repository for the latest packages
emerge --sync

# Read news items
eselect news list
eselect news read

# select correct profile
# take note of the number next to the profile (for this guide we want desktop, systemd, gnome)
eselect profile list | less # use arrow keys to scroll and q to exit
eselect profile set <number>
```
### Setup the Binary Package Host (optional)
The beauty of Gentoo is you can set your own USE flags and packages are installed from source and built locally on your machine
according to your USE flags. But this process makes installing packages slow. We can optionally use the binhost to download
precompiled packages, but only if the USE flags match. Any package with non-matching USE flags is still built locally. Also, not
all packages have a bin available.

```ini
# /etc/portage/binrepos.conf/gentoobinhost.conf
[binhost]
priority = 9999
sync-uri = https://distfiles.gentoo.org/releases/amd64/binpackages/23.0/x86-64/ # URL could change
```

```bash
# /etc/portage/make.conf
FEATURES="${FEATURES} getbinpkg"
```

### VIDEO_CARDS Flag
For any install which will NOT use the terminal (such as a desktop install), the `VIDEO_CARDS` flag should be set
(example AMD GPU):
```bash
# /etc/portage/make.conf
VIDEO_CARDS="amdgpu radeonsi"
```

### Accept Optional Licenses
This step is needed to install the linux-firmware and, if you have an Intel CPU, the Intel microcode:
```bash
# /etc/portage/package.license/kernel
sys-kernel/linux-firmware linux-fw-redistributable
sys-firmware/intel-microcode intel-ucode
```

### Update @world (optional)
This process could take a while if you changed your profile (such as selecting `desktop/gnome/systemd`).

If not using the binhost:
```bash
emerge --ask --verbose --update --deep --changed-use @world
```
If using the binhost:
```bash
emerge --ask --verbose --update --deep --newuse --getbinpkg @world
```

Remove old packages:
```bash
emerge --ask --depclean
```

## Set the Timezone
List the available timezones:
```bash
ls -l /usr/share/zoneinfo
ls -l /use/share/zoneinfo/US

# I want US/Eastern:
ln -sf ../usr/share/zoneinfo/US/Eastern /etc/localtime
```

## Set the Locale
Open `/etc/locale.gen` and uncomment the lines (should be two) for your locale:
```bash
# /etc/locale.gen
en_US ISO-8859-1
en_US.UTF-8 UTF-8
```

```bash
locale-gen
```

```bash
eselect locale list
eselect locale set <NUMBER>
```

If the locale was changed, run:
```bash
env-update && source /etc/profile && export PS1="(chroot) ${PS1}"
```

## Install Firmware
```bash
emerge -a sys-kernel/linux-firmware
```

If you have an AMD CPU, then the microcode is included with the kernel. For users with an Intel CPU, it is necessary to install
the Intel microcode:
```bash
emerge -a sys-firmware/intel-microcode
```

## installkernel
For the GRUB bootloader:
```bash
# /etc/portage/package.use/installkernel
sys-kernel/installkernel dracut grub
```
```bash
emerge -a sys-kernel/installkernel
```

Now we can install the kernel. Using a precompiled bin kernel will make this faster. Setting up the binhost is not required
to do so.
```bash
emerge -a sys-kernel/gentoo-kernel
# OR, for the bin kernel:
emerge -a sys-kernel/gentoo-kernel-bin
```

Many users will elect to build a custom-configured kernel that is specific to their machine. Some users elect to instead continue
using the dist-kernel to avoid the hassle of configuring it themselves. For those users, add to the USE flags:
```bash
# /etc/portage/make.conf
USE="dist-kernel"
```

Congratulations! You've just installed the Linux Kernel on Gentoo! We're not done yet...

## Creating the fstab
The fstab (FS Table, or f-stab) file contains a table which tells the bootloader about all of the disk's partitions and where/how
to mount them. Creating the fstab file can be automated via the `genfstab` package:
```bash
emerge -a sys-fs/genfstab
```
```bash
genfstab -U / >> /etc/fstab

# make sure fstab did everything correctly:
nano /etc/fstab
```
An example of how the fstab should look is available
[here](https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/System#UEFI_systems).

## Set up Networking
First, set your computers hostname. This can be anything and is what your computer will show up as on the network. For example,
we can set it to `gentoo`. Or we can set it to `andrew-pc`. Or anything:
```bash
echo gentoo > /etc/hostname
```

Now install dhcpcd and NetworkManager:
```bash
emerge -a net-misc/dhcpcd net-misc/networkmanager

# and enable both via systemd
systemctl enable dhcpcd
systemctl enable NetworkManager
```

## Systemd Configuration
```bash
systemd-machine-id-setup
systemd-firstboot --prompt
systemctl preset-all --preset-mode=enable-only
```

## System Tools
These are additional tools which are needed/nice-to-have.
```bash
# mlocate: file system indexing
# bash-completion: command completions for bash
# chrony: automatically syncs the system clock on every boot
# btrfs-progs: required filesystem utilities for BTRFS
# io-scheduler-udev-rules: scheduler behavior for NVMe devices
emerge-a sys-apps/mlocate app-shells/bash-completion net-misc/chrony sys-fs/btrfs-progs sys-block/io-scheduler-udev-rules

# enable services:
systemctl enable sshd
systemctl enable chronyd
```

## Install GRUB
```bash
emerge -av sys-boot/grub
```
Notice the `-v` flag on that command. This enable verbose output. Ensure you see `GRUB_PLATFORMS="efi-64 [...]"` in the output.
```bash
grub-install --efi-directory=/efi
grub-mkconfig -o /boot/grub/grub.cfg
```

THAT'S IT! GENTOO IS INSTALLED (hopefully). Now we can reboot the system and hope:

## Rebooting the System
```bash
exit
umount -R /mnt/gentoo
reboot
```

If everything went correctly, your system will reboot and you will have a login prompt for your new installation. For `Login`,
enter `root`, and for the password, just press `ENTER` (no password is set).

## User Admin

### Create a user account

To create a user account, run:
```bash
useradd -m -G users,wheel,audio,video,usb -s /bin/bash andrew # username andrew
passwd andrew # this command is used to set the password for the user
```
Note that the `wheel` group is the administrators group on Linux.

### Install sudo
`sudo` is a command which allows us to run commands as if we were the root account, but without logging in as root.
```bash
emerge -a app-admin/sudo

# enable the sudo command for the wheel group:
EDITOR=nano visudo

# uncomment the line that says "%wheel ALL=(ALL:ALL) ALL"
```

Alternatively, `systemd` already includes `run0` which works similarly to sudo.

### Disable the root account
Disabling the root account is a fundamental part of maintaining system security. First, we will switch to our personal account
and ensure sudo works:
```bash
su andrew # replace with your user account
sudo ls /root
# you should be prompted for your password and the commend should succeed after entering it.

# assuming the above command worked, disable the root account:
sudo passwd -dl root
```

## Install GNOME
Before we get started, start by removing the stage file from earlier:
```bash
rm /stage3-*.tar.*
```

If you switched to your user account (and disabled root), then all commands from this point will need to be run with `sudo` at
the beginning.

GNOME can be easily installed by emerging `gnome-base/gnome` but this will install a lot of extra packages which
we do not necessarily want. Alternatively, we can either use the `-extras` flag on GNOME or install `gnome-light`. We will use the
former option since the latter is too cut down for what we want. Also, this will install the `webkit-gtk` package, which can
take *hours* to install depending on your hardware.

```bash
# /etc/portage/package.use/gnome
gnome-base/gnome -extras
```

Now install GNOME:
```bash
emerge -a gnome-base/gnome

# optionally add additional packages to the end of that command (these are my recs):
app-arch/file-roller              # archive manager
gnome-base/dconf-editor           # graphical editor for dconf files
gnome-extra/gnome-calculator
gnome-extra/gnome-system-monitor  # like task manager, but gnome
gnome-extra/gnome-tweaks          # change hidden settings for gnome
gnome-extra/gnome-weather         # view the weather
sys-apps/baobab                   # disk usage viewer similar to Filelight
sys-apps/gnome-disk-utility
```

Once GNOME is installed, enable and start it:
```bash
systemctl enable --now gdm
```

## Flatpak
Flatpak provides a way to run applications inside containers. This has many advantages including security and compatibility. Any
distribution that can use flatpak can run any flatpak application since flatpak itself handles compatibility. The downside of 
flatpak is it needs to install additional resources for each app in order to achieve compatibility. The result is that any given
app will take more disk space than the non-flatpak equivalent. However, if multiple apps use the same resources, they are NOT
reinstalled. For each flatpak you install, the next one will likely have a smaller footprint.

To install flatpak:
```bash
emerge --ask sys-apps/flatpak
```

Flatpaks must be installed from a repository and the more popular is Flathub:
```bash
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

Install the optional Wayland desktop integration for flatpaks:
```bash
emerge -a sys-apps/xdg-desktop-portal
emerge -a sys-apps/xdg-desktop-portal-gnome sys-apps/xdg-desktop-portal-gtk
```

### Install GNOME Software
GNOME software is an additional app which provides a graphical way to install and uninstall flatpaks. GNOME software cannot be
used with regular system packages. Only Flatpaks.

First, we need a USE flag to tell gnome-software to use flathub:
```bash
# /etc/portage/package.use/gnome-software
gnome-extra/gnome-software flatpak
```
Second, since `gnome-software` isn't marked stable, we need to accept the testing version:
```bash
# /etc/portage/package.accept_keywords/gnome-software
gnome-extra/gnome-software ~amd64
```

Now install `gnome-software`:
```bash
emerge -a gnome-extra/gnome-software
```

## Change MAKEOPTS
At this point, most things are installed. However, each time we install new software, the build process can use all threads on our
CPU. While this is great for speeding up the compile process, it also makes the system slow each time we install or update
packages. To rectify this, we can reduce the number of make jobs:
```bash
# /etc/portage/make.conf
MAKEOPTS="-j4 -l5"
```
Play around and figure out what number works best for you. 1/2 or 1/4 of your total threads is a good starting point. Run `nproc`
if you are not sure how many threads you have.

## Post Install
These are extra things which it might be good to take care of:

#### Use newer kernels
Gentoo normally only marks LTS kernels as stable. The effect is you end up with a kernel that is up to a year old while much
newer versions exist. To enable newer kernels:
```bash
# /etc/portage/package.accept_keywords/kernel
virtual/dist-kernel ~amd64
sys-kernel/gentoo-kernel ~amd64
sys-kernel/gentoo-sources ~amd64
```

#### Pipewire for audio
Pipewire might not work initially. To fix, first set use flags on pipewire and reemerge:
```bash
# /etc/portage/package.use/pipewire
media-video/pipewire pipewire-alsa sound-server
```

Now make sure your user is in the `pipewire` and `audio` groups:
```bash
usermod -aG pipewire,audio andrew
```

Now setup the sound server:
```bash
# might fail, that's fine. DO NOT RUN AS ROOT!
systemctl --user disable --now pulseaudio.socket pulseaudio.service
systemctl --user enable --now pipewire-pulse.socket wireplumber-service
systemctl --user enable --now pipewire.service
```


#### X-Plane support
Gentoo should support X-Plane out of the box if you follow this guide. However many addon airplanes use SASL which, 
annoyingly, will silently fail to load due to an undocumented dependency on OpenAL. (you can use `readelf -d [FILE]`
to view dependencies on any binary.) To install OpenAL:
```bash
emerge -a media-libs/openal
```