```bash                                                 
  ________   ___    _ ______ _____  ____   ____       _____ _   _  _____ _______       _      _      
 |  ____\ \ / / |  | |  ____|  __ \|  _ \ / __ \     |_   _| \ | |/ ____|__   __|/\   | |    | |     
 | |__   \ V /| |__| | |__  | |__) | |_) | |  | |______| | |  \| | (___    | |  /  \  | |    | |     
 |  __|   > < |  __  |  __| |  _  /|  _ <| |  | |______| | | . ` |\___ \   | | / /\ \ | |    | |     
 | |____ / . \| |  | | |____| | \ \| |_) | |__| |     _| |_| |\  |____) |  | |/ ____ \| |____| |____ 
 |______/_/ \_\_|  |_|______|_|  \_\____/ \____/     |_____|_| \_|_____/   |_/_/    \_\______|______|
```
## NVME / ESP / XBOOTLDR / LUKS / SYSTEMD-BOOT / DRACUT
**This guide is based on several documentations**

**Exherbo**
* Title: Installation Guide
* Source: http://exherbolinux.org/docs/install-guide.html

**Systemd**
* Title: The Boot Loader Specification
* Source: https://uapi-group.org/specifications/specs/boot_loader_specification/

**Freedesktop**
* Title: systemd-gpt-auto-generator
* Source: https://www.freedesktop.org/software/systemd/man/systemd-gpt-auto-generator.html

&nbsp;

## 1. Boot a live system
Download [Archlinux](https://www.archlinux.org/download/) ISO and put it on your flash drive:
```
dd bs=4M if=/path/to/archlinux.iso of=/dev/sdX conv=fsync oflag=direct status=progress
```
Reboot

&nbsp;

## 2. Keyboard layout, Wi-Fi setup and SSH (Optional)

Change the keyboard layout:
```bash
sudo loadkeys fr
```

Wifi configuration (optional)
```bash
iwctl
station wlan0 scan
station wlan0 get-networks
station wlan0 connect <SSID>
```

Set password:
```bash
passwd
```

Connect via SSH:
```bash
ssh root@<IP>
```

&nbsp;

## 2. Prepare the hard disk
Disk layout:
```php
+-----------------+ +------------------+ ++--------------------------------------+
|       ESP       | |     XBOOTLDR     | |       LUKS2 encrypted partition       |
|                 | |                  | |                                       |
|                 | |                  | |    _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _    |
|                 | |                  | |   |                               |   |
|                 | |                  | |   |            Exherbo            |   |
|                 | |                  | |   |                               |   |
|   /efi (vfat)   | |   /boot (vfat)   | |   |     /dev/mapper/root (ext4)   |   |
|                 | |                  | |   |_ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _|   |
|                 | |                  | |                                       |
|                 | |                  | |                                       |
| /dev/nvme0n1p1  | |  /dev/nvme0n1p2  | |             /dev/nvme0n1p3            |
|                 | |                  | |                                       |
+-----------------+ +------------------+ ++--------------------------------------+
```

Create a new **GPT** disklabel and three partitions, one for the **ESP** (~100mb), one for the **XBOOTLDR** (~200mb) and another one for the **LUKS container** (the remaining disk space).
```bash
fdisk /dev/nvme0n1

Welcome to fdisk (util-linux 2.36.1).
Changes will remain in memory only, until you decide to write them.
Be careful before using the write command.


Command (m for help): g
Created a new GPT disklabel (GUID: AF3C933D-3C72-4342-8CBA-057327B4FD1A).

Command (m for help): n
Partition number (1-128, default 1):
First sector (2048-1000215182, default 2048):
Last sector, +/-sectors or +/-size{K,M,G,T,P} (2048-1000215182, default 1000215182): +100MB

Created a new partition 1 of type 'Linux filesystem' and of size 95 MiB.

Command (m for help): t
Selected partition 1
Partition type or alias (type L to list all): 1
Changed type of partition 'Linux filesystem' to 'EFI System'.

Command (m for help): n
Partition number (2-128, default 2):
First sector (196608-1000215182, default 196608):
Last sector, +/-sectors or +/-size{K,M,G,T,P} (196608-1000215182, default 1000215182): +200MB

Created a new partition 2 of type 'Linux filesystem' and of size 191 MiB.

Command (m for help): t
Partition number (1,2, default 2):
Partition type or alias (type L to list all): 48

Changed type of partition 'Linux filesystem' to 'Linux extended boot'.

Command (m for help): n
Partition number (3-128, default 3):
First sector (587776-1000215182, default 587776):
Last sector, +/-sectors or +/-size{K,M,G,T,P} (587776-1000215182, default 1000215182):

Created a new partition 3 of type 'Linux filesystem' and of size 476.7 GiB.

Command (m for help): p
Disk /dev/nvme0n1: 476.94 GiB, 512110190592 bytes, 1000215216 sectors
Disk model: WDC PC SN720 SDAQNTW-512G-1001
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: gpt
Disk identifier: AF3C933D-3C72-4342-8CBA-057327B4FD1A

Device          Start        End   Sectors   Size Type
/dev/nvme0n1p1   2048     196607    194560    95M EFI System
/dev/nvme0n1p2 196608     587775    391168   191M Linux extended boot
/dev/nvme0n1p3 587776 1000215182 999627407 476.7G Linux filesystem

Command (m for help): w
The partition table has been altered.
Calling ioctl() to re-read partition table.
Syncing disks.
```

Format EFI Partition:
```bash
mkfs.vfat -F32 /dev/nvme0n1p1
```

Format BOOT Partition:
```bash
mkfs.vfat -F32 /dev/nvme0n1p2
```

Create the LUKS encrypted container and open it:
```bash
cryptsetup --cipher aes-xts-plain64 --hash sha512 --use-random --verify-passphrase luksFormat /dev/nvme0n1p3
cryptsetup open /dev/nvme0n1p3 root
```

Format LUKS container
```bash
mkfs.ext4 /dev/mapper/root
```

Mount everything:
```bash
mount /dev/mapper/root /mnt

mkdir /mnt/{boot,efi}
mount /dev/nvme0n1p1 /mnt/efi
mount /dev/nvme0n1p2 /mnt/boot

mount -o rbind /dev /mnt/dev/
mount -o bind /sys /mnt/sys/
mount -t proc none /mnt/proc/
```

Get the latest automatically-built daily archive of Exherbo from Stages and verify the consistence of the file:
```bash
cd /mnt
curl -O https://stages.exherbolinux.org/x86_64-pc-linux-gnu/exherbo-x86_64-pc-linux-gnu-gcc-current.tar.xz
curl -O https://stages.exherbolinux.org/x86_64-pc-linux-gnu/exherbo-x86_64-pc-linux-gnu-gcc-current.tar.xz.sha256sum
sha256sum -c exherbo-x86_64-pc-linux-gnu-current.tar.xz.sha256sum
```

Extract the stage:

```bash
tar xJpf exherbo*xz
```

&nbsp;

## 3. Chroot into the system

Make sure the network can resolve DNS:
```bash
cp /etc/resolv.conf /mnt/etc/resolv.conf
```

Chroot:
```bash
chroot /mnt /bin/bash
export PS1="(chroot) $PS1"
```

&nbsp;

## 4. Update the install

Sync all the trees – now it is safe to sync
```bash
cave sync
cave resolve world -cx
```

&nbsp;

## 5. Make it bootable

Create fstab:
```bash
vim /etc/fstab

# <file system> <mount point> <type> <options> <dump> <pass>
/dev/disk/by-uuid/6CFA-E9A0 /efi vfat defaults 0 2
/dev/disk/by-uuid/6D44-3BB9 /boot vfat defaults 0 2
/dev/disk/by-uuid/6c7f4030-9559-41a0-b6d5-86d8218c14ec / ext4 defaults 0 1
```

Create crypttab:
```bash
blkid | grep nvme0n1p3
/dev/nvme0n1p3: UUID="5a1558cc-0d27-4795-a2bc-64ffdfc04f8b" TYPE="crypto_LUKS" PARTUUID="c6d92a71-284e-1d41-a5c0-748cf21e53b8"

vim /etc/crypttab
root UUID=5a1558cc-0d27-4795-a2bc-64ffdfc04f8b none luks,cipher=aes-xts-plain64,discard
```

Rebuild systemd with efi and cryptsetup flag:
```bash
echo "sys-apps/systemd cryptsetup efi" >> /etc/paludis/options.conf
cave resolve -x sys-apps/systemd 
```

Install dracut and cryptsetup:
```bash
echo "sys-apps/coreutils xattr" >> /etc/paludis/options.conf
cave resolve -x dracut 
```

Configure dracut:
```bash
echo "compress=\"xz\"" > /etc/dracut.conf.d/compress.conf

echo "force=\"yes\"" > /etc/dracut.conf.d/force.conf

echo "hostonly=\"yes\"" > /etc/dracut.conf.d/hostonly.conf
echo "hostonly_mode=\"strict\"" >> /etc/dracut.conf.d/hostonly.conf

echo "dracutmodules=\"base bash crypt dm dracut-systemd fs-lib i18n kernel-modules rootfs-block systemd systemd-initrd terminfo udev-rules usrmount\"" > /etc/dracut.conf.d/modules.conf
```

Configure console keymap:
```bash
echo KEYMAP=fr > /etc/vconsole.conf
```

Install systemd-boot:
```bash
mount -t efivarfs efivarfs /sys/firmware/efi/efivars
bootctl --make-machine-id-directory=yes --esp-path=/efi --boot-path=/boot install
```

Download and extract the latest stable kernel from [The Linux Kernel Archives](https://www.kernel.org/).

Go to the kernel folder:
```bash
mkdir /usr/src/kernel && cd $_

wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.10.4.tar.xz
tar -xf linux-5.10.4.tar.xz && cd linux-5.10.4
```

Device drivers
```bash
Device Drivers  --->
    NVME Support  --->
        <*> NVM Express block device
    [*] Multiple devices driver support (RAID and LVM) --->
        <*>   Crypt target support
    Graphics support  --->  
        Frame buffer Devices  --->  
	    <*> Support for frame buffer devices  --->
	        [*] EFI-based Framebuffer Support   
```

Cryptographic API:
```bash
[*] Cryptographic API --->
    Length-preserving ciphers and modes  --->
        <*> XTS (XOR Encrypt XOR with ciphertext stealing)
    Compression  --->
        <*> LZ4
        <*> LZ4HC
        <*> Zstd
    Userspace interface  --->
        <*> Hash algorithms
        <*> Symmetric key cipher algorithms
    Accelerated Cryptographic Algorithms for CPU (x86)  --->
        <*> Ciphers: Triple DES EDE with modes: ECB, CBC
```

Security options:
```bash
Security Options --->
    [*] Diffie-Hellman operations on retained keys
```

Build and install kernel/initramfs:
```bash
eclectic installkernel set -2
make -j$(nproc)
make modules_install
make install
```

&nbsp;

## 5. Last step

Configure your hostname:
```bash
echo "laptop" > /etc/hostname
```

Configure hosts:
```bash
echo "127.0.0.1 laptop.local laptop localhost" > /etc/hosts
echo "::1 laptop.local laptop localhost" >> /etc/hosts
```

Additional kernel support (e.g. for an Intel wireless card):
```bash
cave resolve repository/hardware -x
cave resolve -x linux-firmware
```

Locales / LANG / timezone:
```bash
localedef -i en_US -f ISO-8859-1 en_US
echo LANG="en_US.UTF-8" > /etc/env.d/99locale
ln -s /usr/share/zoneinfo/Europe/Paris /etc/localtime
```

Install iwd:
```bash
cave resolve -x iwd
```

Enable service:
```bash
systemctl enable getty@ iwd dhcpcd
```

Set root password:
```bash
passwd
```

&nbsp;

## 8. Reboot

:hocho: **+** :goat: **+** :pray: