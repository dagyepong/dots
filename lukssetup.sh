# [Gentoo Linux](https://gentoo.org) Installation Guide
# Encrypted Btrfs + Encrypted Swap + OpenRC + EFI Stub Boot + Secure Boot + TPM
# Complete setup including swap partition /dev/nvme0n1p3

# =================================================================
# BOOT AND PREPARATION
# =================================================================

# Boot from a valid [Gentoo ISO](https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Media#Gentoo_Linux_installation_media)
# Configure the [network](https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Networking#Automatic_network_configuration)
# Set up [SSH](https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Media#Optional:_Starting_the_SSH_daemon) if possible

# =================================================================
# PARTITIONING
# =================================================================

cfdisk /dev/nvme0n1

# Device          Start       End         Sectors    Size   Type
# /dev/nvme0n1p1  882423808   884520959   2097152    1G     EFI System
# /dev/nvme0n1p2  34816       629198847   629164032  300G   Linux filesystem
# /dev/nvme0n1p3  629198848   645198847   16000000   7.63G  Linux swap

# =================================================================
# DISK ENCRYPTION
# =================================================================

# Encrypt root partition
cryptsetup luksFormat --type luks2 --cipher aes-xts-plain64 --key-size 512 \
    --pbkdf argon2id --pbkdf-memory 1048576 --iter-time 4000 \
    --label "GentooLuks" /dev/nvme0n1p2

# Encrypt swap partition
cryptsetup luksFormat --type luks2 --cipher aes-xts-plain64 --key-size 512 \
    --pbkdf argon2id --pbkdf-memory 1048576 --iter-time 4000 \
    --label "SwapLuks" /dev/nvme0n1p3

# Open encrypted devices
cryptsetup open /dev/nvme0n1p2 root
cryptsetup open --type luks2 /dev/nvme0n1p3 swap

# =================================================================
# FILESYSTEM CREATION
# =================================================================

# Create filesystems
mkfs.vfat -n GentooBoot -F 32 /dev/nvme0n1p1
mkfs.btrfs -L GentooRoot /dev/mapper/root

# Format and activate swap
mkswap -L GentooSwap /dev/mapper/swap
swapon /dev/mapper/swap

# =================================================================
# BTRFS SUBVOLUMES AND MOUNTS
# =================================================================

mkdir -p /mnt/gentoo
mount LABEL=GentooRoot /mnt/gentoo/

# Create btrfs subvolumes
btrfs su cr /mnt/gentoo/{@,@home,@.snapshots,@usr,@opt,@srv,@db,@log,@tmp,@crash,@spool,@portage,@NetworkManager,@binpkgs,@distfiles,@boot}

umount -l /mnt/gentoo

# Mount root subvolume
mount -o subvol=@ LABEL=GentooRoot /mnt/gentoo

# Create directory structure
mkdir -p /mnt/gentoo/{home,.snapshots,usr,opt,srv,boot,efi,var/{db,log,tmp,crash,spool,lib/{portage,NetworkManager},cache/{binpkgs,distfiles}}}

# Mount all subvolumes
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

# =================================================================
# STAGE3 INSTALLATION
# =================================================================

cd /mnt/gentoo

# Download stage3 (adjust version as needed)
wget https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-hardened-openrc/stage3-amd64-hardened-openrc-*.tar.xz
wget https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-hardened-openrc/stage3-amd64-hardened-openrc-*.tar.xz.asc

# Verify signature
gpg --import /usr/share/openpgp-keys/gentoo-release.asc
gpg --verify stage3-amd64-hardened-openrc-*.tar.xz.asc

# Extract stage3
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner -C /mnt/gentoo

# =================================================================
# CONFIGURE PORTAGE
# =================================================================

cat > /mnt/gentoo/etc/portage/make.conf << 'EOF'
COMMON_FLAGS="-march=native -O2 -pipe"
ACCEPT_LICENSE="*"
FEATURES="${FEATURES} getbinpkg"
FEATURES="${FEATURES} binpkg-request-signature"
USE="dist-kernel"
EOF

# Copy DNS info
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/

# =================================================================
# CHROOT PREPARATION
# =================================================================

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

# =================================================================
# SYSTEM CONFIGURATION IN CHROOT
# =================================================================

# Update Portage tree
emerge-webrsync
getuto

# Select mirrors
emerge --ask --verbose --oneshot app-portage/mirrorselect
mirrorselect -i -o >> /etc/portage/make.conf
emerge --sync

# Select profile
eselect profile list
# Choose: [21] default/linux/amd64/23.0/hardened (stable) *
eselect profile set 21

# CPU optimizations
emerge --ask --oneshot app-portage/cpuid2cpuflags
cpuid2cpuflags
echo "*/* $(cpuid2cpuflags)" > /etc/portage/package.use/00cpu-flags

# Update system
emerge -avuDUg @world
emerge --ask --pretend --depclean
emerge --ask --depclean

# Install editor
emerge --ask app-editors/nano

# =================================================================
# LOCALIZATION
# =================================================================

cat > /etc/locale.gen << 'EOF'
en_US.UTF-8 UTF-8
EOF

locale-gen
eselect locale set 4
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
env-update && source /etc/profile && export PS1="(chroot) ${PS1}"

# =================================================================
# KERNEL AND INITRAMFS
# =================================================================

echo "sys-kernel/installkernel dracut" >> /etc/portage/package.use/installkernel

# Install required packages
emerge --ask sys-kernel/linux-firmware sys-firmware/sof-firmware \
    sys-fs/btrfs-progs sys-fs/cryptsetup sys-kernel/installkernel

# Configure crypttab for encrypted swap
cat > /etc/crypttab << 'EOF'
# name  source device      keyfile            options
swap    /dev/nvme0n1p3     /dev/urandom       swap,cipher=aes-xts-plain64,size=512
EOF

# Configure dracut
cat > /etc/dracut.conf << 'EOF'
hostonly="yes"
hostonly_mode=strict
add_dracutmodules+=" crypt "
EOF

# Install kernel
emerge --ask sys-kernel/gentoo-kernel-bin

# =================================================================
# FILESYSTEM TABLES
# =================================================================

cat > /etc/fstab << 'EOF'
# Root filesystem
LABEL=GentooRoot / btrfs rw,nodev,noatime,lazytime,skip_balance,nodatacow,ssd,discard,space_cache=v2,commit=120,subvol=/@ 0 0

# Subvolumes
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

# EFI partition
LABEL=GentooBoot /efi vfat rw,nosuid,nodev,noexec,relatime,fmask=0077,dmask=0077,codepage=437,iocharset=ascii,shortname=mixed,utf8,discard,flush,errors=remount-ro	0 2

# Encrypted swap
/dev/mapper/swap none swap sw,discard 0 0
EOF

# =================================================================
# SYSTEM TOOLS AND CONFIGURATION
# =================================================================

emerge --ask --autounmask-continue app-admin/sudo app-shells/bash-completion net-misc/networkmanager

# Create user
useradd -m -s /bin/bash -G audio,video,wheel username
echo "username:password" | chpasswd
echo "username ALL=(ALL) ALL" >> /etc/sudoers

# Hostname
echo "gentoo" > /etc/hostname

# Clock configuration
cat > /etc/conf.d/hwclock << 'EOF'
clock="local"
clock_systohc="YES"
EOF

# OpenRC configuration
cat > /etc/rc.conf << 'EOF'
rc_parallel="YES"
rc_autostart_user="NO"
EOF

# =================================================================
# EFI STUB BOOT CONFIGURATION
# =================================================================

mkdir -p /etc/portage/package.accept_keywords
cat > /etc/portage/package.accept_keywords/installkernel << 'EOF'
sys-kernel/installkernel
sys-boot/uefi-mkconfig
app-emulation/virt-firmware
EOF

echo "sys-kernel/installkernel efistub" >> /etc/portage/package.use/installkernel

# Rebuild installkernel
emerge sys-kernel/installkernel

mkdir -p /efi/EFI/Gentoo

# Generate initramfs
installkernel -a /lib/modules

# Configure kernel parameters
cat > /etc/default/uefi-mkconfig << 'EOF'
KERNEL_CONFIG="%entry_id %linux_name Linux %kernel_version ; rd.luks.label=GentooLuks root=LABEL=GentooRoot rootfstype=btrfs rootflags=subvol=@ video=efifb:mode=0 resume=/dev/mapper/swap"
EOF

# Create boot entry
uefi-mkconfig

# =================================================================
# SECURE BOOT SETUP
# =================================================================

emerge --ask app-crypt/efitools app-crypt/sbsigntools dev-libs/openssl

# Key generation
dmesg | grep -i "secure"  # Check Secure Boot status

mkdir -p /etc/efikeys && cd /etc/efikeys

# Save current keys
efi-readvar -v PK -o old_PK.esl
efi-readvar -v KEK -o old_KEK.esl
efi-readvar -v db -o old_db.esl
efi-readvar -v dbx -o old_dbx.esl

# Create GUID
uuidgen --random > guid.txt

# Create new keypairs
openssl req -new -x509 -newkey rsa:4096 -subj "/CN=My Platform Key/" -keyout pk.key -out pk.crt -days 3650 -nodes -sha512
openssl req -new -x509 -newkey rsa:4096 -subj "/CN=My Key Exchange Key/" -keyout kek.key -out kek.crt -days 3650 -nodes -sha512
openssl req -new -x509 -newkey rsa:4096 -subj "/CN=My Signature DB Key/" -keyout db.key -out db.crt -days 3650 -nodes -sha512

# Create signature lists
cert-to-efi-sig-list -g "$(< guid.txt)" pk.crt pk.esl
sign-efi-sig-list -k pk.key -c pk.crt PK pk.esl pk.auth

cert-to-efi-sig-list -g "$(< guid.txt)" kek.crt kek.esl
cert-to-efi-sig-list -g "$(< guid.txt)" db.crt db.esl

# Combine with old keys
cat old_KEK.esl kek.esl > combined_KEK.esl
cat old_db.esl db.esl > combined_db.esl

# Enroll keys (requires Secure Boot in setup mode)
efi-updatevar -e -f old_dbx.esl dbx
efi-updatevar -e -f combined_db.esl db
efi-updatevar -e -f combined_KEK.esl KEK
efi-updatevar -f pk.auth PK

# Remove unsigned EFI binaries
rm -f /efi/EFI/Gentoo/*

# Sign kernel
sbsign --key /etc/efikeys/db.key \
       --cert /etc/efikeys/db.crt \
       --output "/lib/modules/$(uname -r)/vmlinuz" \
       "/lib/modules/$(uname -r)/vmlinuz"

# Regenerate kernel with signature
installkernel

# Verify signature
sbverify --cert /etc/efikeys/db.crt /efi/EFI/Gentoo/vmlinuz-$(uname -r).efi

# =================================================================
# TPM INTEGRATION WITH CLEVIS
# =================================================================

emerge --ask app-eselect/eselect-repository 
eselect repository enable guru && emerge --sync
ACCEPT_KEYWORDS="~amd64" emerge -a app-crypt/clevis

# Encrypt Secure Boot key with TPM
clevis encrypt tpm2 '{"pcr_bank":"sha256","pcr_ids":"0"}' < /etc/efikeys/db.key > /etc/efikeys/db.key.jwe

# Automated kernel signing hook
mkdir -p /etc/portage/env/sys-kernel

cat > /etc/portage/env/sys-kernel/gentoo-kernel-bin << 'EOF'
pre_pkg_postinst() {
sbsign --key <(clevis decrypt < /etc/efikeys/db.key.jwe) \
       --cert /etc/efikeys/db.crt \
       --output "/lib/modules/$(uname -r)/vmlinuz" \
       "/lib/modules/$(uname -r)/vmlinuz"
}
EOF

chmod +x /etc/portage/env/sys-kernel/gentoo-kernel-bin

# Bind LUKS to TPM
clevis luks bind -d /dev/nvme0n1p2 tpm2 '{"pcr_bank":"sha256","pcr_ids":"0,7,9"}'

# Regenerate initramfs with TPM support
installkernel

# =================================================================
# FINALIZATION
# =================================================================

# Rebuild kernel with TPM signing
emerge -1 gentoo-kernel-bin

# Verify all EFI binaries
sbverify --cert /etc/efikeys/db.crt /efi/EFI/Gentoo/vmlinuz-$(uname -r).efi
sbverify --cert /etc/efikeys/db.crt /efi/EFI/Gentoo/vmlinuz-$(uname -r)-old.efi

# Set root password
echo "Set root password:"
passwd

# =================================================================
# REBOOT
# =================================================================

echo "Installation complete! Rebooting..."
echo "After reboot, you may need to:"
echo "1. Log in as root or your created user"
echo "2. Start NetworkManager: rc-service NetworkManager start"
echo "3. Add NetworkManager to default runlevel: rc-update add NetworkManager default"
echo ""
echo "Press Enter to reboot or Ctrl+C to cancel"
read
reboot
