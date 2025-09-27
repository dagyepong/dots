# [Gentoo linux](https://gentoo.org) [installation](https://codeberg.org/sabuj/GentooLinux_Installation#readme) [encrypted](#2) [btrfs](#3) [openrc](#4) [EFI stub boot](#5) [secure boot](#6) [tpm](#7)
Boot from a valid [Gentoo ISO](https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Media#Gentoo_Linux_installation_media), configure the [network](https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Networking#Automatic_network_configuration), and set up [SSH](https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Media#Optional:_Starting_the_SSH_daemon) if possible.
### Set up your UEFI Standard partition layout
```bash
cfdisk /dev/nvme0n1

Device          Start       End         Sectors    Size   Type
/dev/nvme0n1p1  882423808   884520959   2097152    1G     EFI System
/dev/nvme0n1p2  34816       629198847   629164032  300G   Linux filesystem
```
#### Encrypt your block device for root filesystem{#2}
```bash
cryptsetup luksFormat --type luks2 --cipher aes-xts-plain64 --key-size 512 --pbkdf argon2id --pbkdf-memory 1048576 --iter-time 4000 --label "GentooLuks" /dev/nvme0n1p2

cryptsetup open /dev/nvme0n1p2 root
```
#### Create filesystems{#3}
```bash
mkfs.vfat -n GentooBoot -F 32 /dev/nvme0n1p1
mkfs.btrfs -L GentooRoot /dev/mapper/root
```
#### Setup Mounts
```bash
mkdir -p /mnt/gentoo
mount LABEL=GentooRoot /mnt/gentoo/

# Create btrfs subvolumes accordingly your needs
btrfs su cr /mnt/gentoo/{@,@home,@.snapshots,@usr,@opt,@srv,@db,@log,@tmp,@crash,@spool,@portage,@NetworkManager,@binpkgs,@distfiles,@boot}

umount -l /mnt/gentoo

mount -o subvol=@ LABEL=GentooRoot /mnt/gentoo

mkdir -p /mnt/gentoo/{home,.snapshots,usr,opt,srv,boot,efi,var/{db,log,tmp,crash,spool,lib/{portage,NetworkManager},cache/{binpkgs,distfiles}}}

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
mount LABEL=GentooBoot /mnt/gentoo/efi
```
#### Download your preferred openrc stage3 file and verify its integrity{#4}
Some LLVM/musl Stages may not work
```bash
cd /mnt/gentoo
wget stage3-amd64-hardened-openrc-xxxx.tar.xz
wget stage3-amd64-hardened-openrc-xxxx.tar.xz.asc

gpg --import /usr/share/openpgp-keys/gentoo-release.asc
gpg --verify stage3-amd64-<release>-<init>.tar.xz.asc

# Once verified, extract it
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner -C /mnt/gentoo
```
#### Configuring portage
`nano /mnt/gentoo/etc/portage/make.conf`
```bash
COMMON_FLAGS="-march=native -O2 -pipe"
ACCEPT_LICENSE="*"
FEATURES="${FEATURES} getbinpkg"
FEATURES="${FEATURES} binpkg-request-signature"
```
#### Copy DNS info
```
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/
```
### Preparing for the chroot
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
#### Configure the system
```bash
# Fetch the latest snapshots
emerge-webrsync

# Setting up for binary packages
getuto

# Pick the nearest mirrors
emerge --ask --verbose --oneshot app-portage/mirrorselect
mirrorselect -i -o >> /etc/portage/make.conf

# Update the Gentoo ebuild repository
emerge --sync

# Choose your preferred openrc profile (Some LLVM/musl profiles may not work)
eselect profile list
[21] default/linux/amd64/23.0/hardened (stable) *

eselect profile set 21

# Enable cpu specific optimizations
emerge --ask --oneshot app-portage/cpuid2cpuflags
cpuid2cpuflags
echo "*/* $(cpuid2cpuflags)" > /etc/portage/package.use/00cpu-flags

# Update the @world set
emerge -avuDUg @world

# Review & remove obsolete packages
emerge --ask --pretend --depclean
emerge --ask --depclean

# Install your preferred text editor
emerge --ask app-editors/nano
```
#### Set up localizations
`nano /etc/locale.gen`
```bash
en_US.UTF-8 UTF-8
```
```bash
locale-gen

eselect locale list
[4]  en_US.utf8 *
eselect locale set 4

ln -sf /usr/share/zoneinfo/YourRegion/City /etc/localtime

env-update && source /etc/profile && export PS1="(chroot) ${PS1}"
```
#### Configure installkernel for initramfs
```bash
echo "sys-kernel/installkernel dracut" >> /etc/portage/package.use/installkernel
```
#### Install some required packages
```bash
emerge --ask sys-kernel/linux-firmware sys-firmware/sof-firmware sys-fs/btrfs-progs sys-fs/cryptsetup sys-kernel/installkernel
```
#### Configure dracut
`nano /etc/dracut.conf`
```bash
hostonly="yes"
hostonly_mode=strict
add_dracutmodules+=" crypt "
```
#### Installing a distribution kernel
```bash
emerge --ask sys-kernel/gentoo-kernel-bin

echo 'USE="dist-kernel"' >> /etc/portage/make.conf
```
#### Add fsbab mounts
`nano /etc/fstab`
```bash
LABEL=GentooRoot / btrfs rw,nodev,noatime,lazytime,skip_balance,nodatacow,ssd,discard,space_cache=v2,commit=120,subvol=/@ 0 0
LABEL=GentooRoot /home btrfs rw,nodev,noatime,lazytime,skip_balance,nodatacow,ssd,discard,space_cache=v2,commit=120,subvol=/@home 0 0
LABEL=GentooRoot /.snapshots btrfs rw,nodev,noatime,lazytime,skip_balance,nodatacow,ssd,discard,space_cache=v2,commit=120,subvol=/@.snapshots	0 0
LABEL=GentooRoot /usr btrfs rw,nodev,noatime,lazytime,skip_balance,nodatacow,ssd,discard,space_cache=v2,commit=120,subvol=/@usr	0 0
LABEL=GentooRoot /opt btrfs rw,nodev,noatime,lazytime,skip_balance,nodatacow,ssd,discard,space_cache=v2,commit=120,subvol=/@opt 0 0
LABEL=GentooRoot /srv btrfs rw,nodev,noatime,lazytime,skip_balance,nodatacow,ssd,discard,space_cache=v2,commit=120,subvol=/@srv 0 0
LABEL=GentooRoot /var/db btrfs rw,nosuid,nodev,noexec,noatime,lazytime,skip_balance,ssd,discard,space_cache=v2,compress-force=zstd:10,commit=120,subvol=/@db	0 0
LABEL=GentooRoot /var/log btrfs rw,nosuid,nodev,noexec,noatime,lazytime,skip_balance,nodatacow,ssd,discard,space_cache=v2,commit=120,subvol=/@log	0 0
LABEL=GentooRoot /var/tmp btrfs rw,nosuid,nodev,noatime,lazytime,skip_balance,nodatacow,ssd,discard,space_cache=v2,commit=120,subvol=/@tmp	0 0
LABEL=GentooRoot /var/crash btrfs rw,nosuid,nodev,noexec,noatime,lazytime,skip_balance,nodatacow,ssd,discard,space_cache=v2,commit=120,subvol=/@crash	0 0
LABEL=GentooRoot /var/spool btrfs rw,nodev,noatime,lazytime,skip_balance,nodatacow,ssd,discard,space_cache=v2,commit=120,subvol=/@spool 0 0
LABEL=GentooRoot /var/lib/portage btrfs rw,nodev,noatime,lazytime,skip_balance,nodatacow,ssd,discard,space_cache=v2,commit=120,subvol=/@portage 0 0
LABEL=GentooRoot /var/lib/NetworkManager btrfs rw,nodev,noatime,lazytime,skip_balance,nodatacow,ssd,discard,space_cache=v2,commit=120,subvol=/@NetworkManager 0 0
LABEL=GentooRoot /var/cache/binpkgs btrfs rw,nosuid,nodev,noexec,noatime,lazytime,skip_balance,ssd,discard,space_cache=v2,compress-force=zstd:10,commit=120,subvol=/@binpkgs 0 0
LABEL=GentooRoot /var/cache/distfiles btrfs rw,nosuid,nodev,noexec,noatime,lazytime,skip_balance,ssd,discard,space_cache=v2,compress-force=zstd:10,commit=120,subvol=/@distfiles 0 0
LABEL=GentooRoot /boot btrfs rw,nosuid,nodev,noexec,noatime,lazytime,skip_balance,nodatacow,ssd,discard,space_cache=v2,commit=120,subvol=/@boot 0 0
LABEL=GentooBoot /efi vfat rw,nosuid,nodev,noexec,relatime,fmask=0077,dmask=0077,codepage=437,iocharset=ascii,shortname=mixed,utf8,discard,flush,errors=remount-ro	0 2
```
#### Installing some necessary system tools
```bash
emerge --ask --autounmask-continue app-admin/sudo app-shells/bash-completion net-misc/networkmanager
```
```bash
# Add sudo privileged user account
useradd -m -s /bin/bash -G audio,video username
passwd username

EDITOR=nano visudo
username ALL=(ALL) ALL

# Set the hostname
echo gentoo > /etc/hostname
```
Configure the clock options

`nano /etc/conf.d/hwclock`
```bash
clock="local"
clock_systohc="YES"
```
Configure OpenRC

`nano /etc/rc.conf`
```bash
rc_parallel="YES"
rc_autostart_user="NO"
```
#### Configure installkernel for automated efistub booting{#5}
`nano /etc/portage/package.accept_keywords/installkernel`
```bash
sys-kernel/installkernel
sys-boot/uefi-mkconfig
app-emulation/virt-firmware
```
```bash
echo "sys-kernel/installkernel efistub" >> /etc/portage/package.use/installkernel

# And Rebuild the installkernel
emerge sys-kernel/installkernel

mkdir -p /efi/EFI/Gentoo

# Generate initramfs again using installkernel
installkernel -a /lib/modules
```
#### Configure kernel parameters
`nano /etc/default/uefi-mkconfig`
```bash
KERNEL_CONFIG="%entry_id %linux_name Linux %kernel_version ; rd.luks.label=GentooLuks root=LABEL=GentooRoot rootfstype=btrfs rootflags=subvol=@ video=efifb:mode=0"
```
#### Finalize and reboot
```bash
# Create a boot entry
uefi-mkconfig

# If your EFI stub boot isn't working, consider using other boot methods
reboot
```
#### Configure Secure Boot{#6}
```bash
emerge --ask app-crypt/efitools app-crypt/sbsigntools dev-libs/openssl
```
#### Key generation
```bash
# Disable secureboot if you haven’t already
dmesg | grep -i "secure"  # Checking Secure Boot Status

mkdir -p /etc/efikeys && cd /etc/efikeys

# Saving the current keys
efi-readvar -v PK -o old_PK.esl
efi-readvar -v KEK -o old_KEK.esl
efi-readvar -v db -o old_db.esl
efi-readvar -v dbx -o old_dbx.esl

# Creating a GUID
uuidgen --random > guid.txt

# Creating new keypairs
openssl req -new -x509 -newkey rsa:4096 -subj "/CN=My Platform Key/" -keyout pk.key -out pk.crt -days 3650 -nodes -sha512
openssl req -new -x509 -newkey rsa:4096 -subj "/CN=My Key Exchange Key/" -keyout kek.key -out kek.crt -days 3650 -nodes -sha512
openssl req -new -x509 -newkey rsa:4096 -subj "/CN=My Signature DB Key/" -keyout db.key -out db.crt -days 3650 -nodes -sha512

# Creating signature lists and sign with the created keys
cert-to-efi-sig-list -g "$(< guid.txt)" pk.crt pk.esl
sign-efi-sig-list -k pk.key -c pk.crt PK pk.esl pk.auth

cert-to-efi-sig-list -g "$(< guid.txt)" kek.crt kek.esl
cert-to-efi-sig-list -g "$(< guid.txt)" db.crt db.esl

# Now combining them with the older keys
cat old_KEK.esl kek.esl > combined_KEK.esl
cat old_db.esl db.esl > combined_db.esl
```
#### Enrolling the keys
Reset Secure Boot to setup mode & update the Secure Boot database
```bash
efi-updatevar -e -f old_dbx.esl dbx
efi-updatevar -e -f combined_db.esl db
efi-updatevar -e -f combined_KEK.esl KEK
efi-updatevar -f pk.auth PK
```
#### Enabling Secure Boot
```bash
# Remove all unsigned EFI binaries from ESP
rm /efi/EFI/Gentoo/*

# Now sign the module
sbsign --key /etc/efikeys/db.key \
       --cert /etc/efikeys/db.crt \
       --output "/lib/modules/$(uname -r)/vmlinuz" \
       "/lib/modules/$(uname -r)/vmlinuz"

# And generate the module
installkernel

# Verify the EFI Binary & Enable the Secure Boot
sbverify --cert /etc/efikeys/db.crt /efi/EFI/Gentoo/vmlinuz-$(uname -r).efi
```
#### Encryption setup with using Clevis
Add the guru repository to install clevis
```bash
emerge --ask app-eselect/eselect-repository 
eselect repository enable guru && emerge --sync

ACCEPT_KEYWORDS="~amd64" emerge -a app-crypt/clevis
```
#### Secure Boot key encryption{#7}
Encrypt the Signature DB and bind it to the TPM PCR
```bash
clevis encrypt tpm2 '{"pcr_bank":"sha256","pcr_ids":"0"}' < /etc/efikeys/db.key > /etc/efikeys/db.key.jwe
```
Now you can store your important keys on the safe place
#### Automated module signing with an emerge phase hook
Ensure TPM is functioning correctly and the `db.crt` and `db.key.jwe` files are accessible from their specified paths, then `sbsign` should sign the module during the kernel installation
```bash
mkdir -p /etc/portage/env/sys-kernel
```
`nano /etc/portage/env/sys-kernel/gentoo-kernel-bin`
```bash
pre_pkg_postinst() {
sbsign --key <(clevis decrypt < /etc/efikeys/db.key.jwe) \
       --cert /etc/efikeys/db.crt \
       --output "/lib/modules/$(uname -r)/vmlinuz" \
       "/lib/modules/$(uname -r)/vmlinuz"
}
```
```bash
# Script should have execute permissions
chmod +x /etc/portage/env/sys-kernel/gentoo-kernel-bin

# Now rebuild the kernel and verify the EFI binaries
emerge -1 gentoo-kernel-bin

sbverify --cert /etc/efikeys/db.crt /efi/EFI/Gentoo/vmlinuz-$(uname -r).efi
sbverify --cert /etc/efikeys/db.crt /efi/EFI/Gentoo/vmlinuz-$(uname -r)-old.efi
```
#### Auto Luks2 unlocking
Check out the [Gentoo wiki](https://wiki.gentoo.org/wiki/Trusted_Platform_Module/LUKS) before proceeding, it may have bugs
```bash
clevis luks bind -d /dev/nvme0n1p2 tpm2 '{"pcr_bank":"sha256","pcr_ids":"0,7,9"}'

# Then regenerate the initramfs
installkernel
```
---
#### If you experience any issues during installation, please follow the official Gentoo Linux [Installation guide](https://wiki.gentoo.org/wiki/Handbook:AMD64). I used references from [Gentoo Wiki](https://wiki.gentoo.org) and [ArchWiki](https://wiki.archlinux.org) with some minor tweaks myself. I hope you find something helpful.