#!/bin/bash

# Gentoo Auto-Installer Script
# Features: OpenRC, LUKS encryption, gentoo-kernel-bin
# Usage: Run from Gentoo live CD/USB

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Initial setup and warnings
welcome_message() {
    log_warning "GENTOO AUTO-INSTALLER SCRIPT"
    log_warning "============================="
    log_warning "This script will:"
    log_warning "1. Partition your disk (will destroy all data!)"
    log_warning "2. Setup LUKS encryption"
    log_warning "3. Install Gentoo with OpenRC"
    log_warning "4. Use gentoo-kernel-bin for faster installation"
    echo
    log_warning "Ensure you have:"
    log_warning "- Internet connection"
    log_warning "- Gentoo live USB"
    log_warning "- Backed up important data"
    echo
    read -p "Continue? (yes/no): " confirm
    if [[ $confirm != "yes" ]]; then
        log_info "Installation cancelled"
        exit 0
    fi
}

# Gather user input
get_user_input() {
    echo
    log_info "Disk configuration"
    lsblk
    echo
    read -p "Enter target disk (e.g., sda, nvme0n1): " DISK
    read -p "Enter hostname: " HOSTNAME
    read -p "Enter username: " USERNAME
    read -s -p "Enter root password: " ROOT_PASSWORD
    echo
    read -s -p "Enter LUKS password: " LUKS_PASSWORD
    echo
    read -s -p "Repeat LUKS password: " LUKS_PASSWORD_REPEAT
    echo
    
    if [[ "$LUKS_PASSWORD" != "$LUKS_PASSWORD_REPEAT" ]]; then
        log_error "LUKS passwords don't match!"
        exit 1
    fi
}

# Set variables based on disk type
setup_disk_vars() {
    if [[ $DISK == nvme* ]]; then
        DISK_PATH="/dev/${DISK}"
        BOOT_PART="${DISK_PATH}p1"
        LUKS_PART="${DISK_PATH}p2"
    else
        DISK_PATH="/dev/${DISK}"
        BOOT_PART="${DISK_PATH}1"
        LUKS_PART="${DISK_PATH}2"
    fi
    
    LUKS_MAPPER="cryptroot"
}

# Partition disk
partition_disk() {
    log_info "Partitioning disk ${DISK_PATH}"
    
    # Clear existing partitions
    sgdisk -Z ${DISK_PATH}
    
    # Create GPT partition table
    parted -s ${DISK_PATH} mklabel gpt
    
    # Create boot partition (512M)
    parted -s ${DISK_PATH} mkpart primary fat32 1MiB 513MiB
    parted -s ${DISK_PATH} set 1 esp on
    
    # Create root partition (remaining space)
    parted -s ${DISK_PATH} mkpart primary 513MiB 100%
    
    log_success "Disk partitioned successfully"
}

# Setup LUKS encryption
setup_luks() {
    log_info "Setting up LUKS encryption"
    
    # Format partition with LUKS
    echo -n "$LUKS_PASSWORD" | cryptsetup luksFormat --type luks2 ${LUKS_PART} -
    
    # Open LUKS container
    echo -n "$LUKS_PASSWORD" | cryptsetup open ${LUKS_PART} ${LUKS_MAPPER}
    
    log_success "LUKS encryption setup complete"
}

# Create filesystems
create_filesystems() {
    log_info "Creating filesystems"
    
    # Format boot partition
    mkfs.fat -F32 ${BOOT_PART}
    
    # Format root partition
    mkfs.ext4 /dev/mapper/${LUKS_MAPPER}
    
    log_success "Filesystems created"
}

# Mount partitions
mount_partitions() {
    log_info "Mounting partitions"
    
    # Mount root
    mount /dev/mapper/${LUKS_MAPPER} /mnt/gentoo
    
    # Create and mount boot
    mkdir -p /mnt/gentoo/boot
    mount ${BOOT_PART} /mnt/gentoo/boot
    
    log_success "Partitions mounted"
}

# Install stage3
install_stage3() {
    log_info "Installing Stage3"
    
    cd /mnt/gentoo
    
    # Get latest stage3 openrc
    LATEST_STAGE3=$(curl -s https://distfiles.gentoo.org/releases/amd64/autobuilds/latest-stage3-amd64-openrc.txt | grep -v '^#' | cut -d' ' -f1)
    STAGE3_URL="https://distfiles.gentoo.org/releases/amd64/autobuilds/${LATEST_STAGE3}"
    
    log_info "Downloading: ${STAGE3_URL}"
    wget ${STAGE3_URL}
    
    # Extract
    tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner
    
    log_success "Stage3 installed"
}

# Configure basic system
configure_system() {
    log_info "Configuring basic system"
    
    # Copy DNS info
    cp -L /etc/resolv.conf /mnt/gentoo/etc/
    
    # Mount necessary filesystems
    mount -t proc /proc /mnt/gentoo/proc
    mount --rbind /sys /mnt/gentoo/sys
    mount --rbind /dev /mnt/gentoo/dev
    
    # Create fstab
    cat > /mnt/gentoo/etc/fstab << EOF
# <fs>          <mountpoint>    <type>    <opts>          <dump/pass>
${BOOT_PART}    /boot           vfat      defaults        0 2
/dev/mapper/${LUKS_MAPPER} /    ext4      defaults        0 1
EOF

    log_success "Basic system configured"
}

# Chroot and continue installation
chroot_install() {
    log_info "Entering chroot environment"
    
    # Create chroot script
    cat > /mnt/gentoo/root/install.sh << 'EOF'
#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Configure Portage
log_info "Configuring Portage"

# Make.conf
cat > /etc/portage/make.conf << MAKECONFEOF
COMMON_FLAGS="-O2 -pipe"
CFLAGS="\${COMMON_FLAGS}"
CXXFLAGS="\${COMMON_FLAGS}"
FCFLAGS="\${COMMON_FLAGS}"
FFLAGS="\${COMMON_FLAGS}"

MAKEOPTS="-j$(nproc)"

ACCEPT_LICENSE="*"
EMERGE_DEFAULT_OPTS="--jobs=$(nproc) --load-average=$(nproc) --quiet-build=y"

GENTOO_MIRRORS="https://distfiles.gentoo.org https://mirror.leaseweb.com/gentoo"

USE="X acl bash-completion dbus elogind gnome-keyring gtk pam pulseaudio ssh systemd udisks wifi"

GRUB_PLATFORMS="efi-64"

LC_MESSAGES=C
MAKECONFEOF

# Configure repositories
mkdir -p /etc/portage/repos.conf
cp /usr/share/portage/config/repos.conf /etc/portage/repos.conf/gentoo.conf

# Update world
log_info "Syncing Portage tree"
emerge-webrsync
emerge --sync

# Set profile
log_info "Setting profile"
eselect profile set 1

# Timezone
echo "Europe/London" > /etc/timezone
emerge --config sys-libs/timezone-data

# Locale
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
echo "en_US ISO-8859-1" >> /etc/locale.gen
locale-gen
eselect locale set en_US.utf8

# Environment
env-update
source /etc/profile

# Install kernel
log_info "Installing gentoo-kernel-bin"
emerge --ask=n sys-kernel/gentoo-kernel-bin

# Install firmware
emerge --ask=n sys-kernel/linux-firmware

# Install tools
log_info "Installing system tools"
emerge --ask=n app-admin/sudo sys-apps/pciutils \
    sys-apps/usbutils net-misc/dhcpcd sys-fs/cryptsetup \
    sys-boot/grub net-wireless/iw net-wireless/wpa_supplicant

# Configure hostname
echo 'HOSTNAME="'"${HOSTNAME}"'"' > /etc/conf.d/hostname

# Configure network (DHCP)
emerge --ask=n net-misc/dhcpcd
rc-update add dhcpcd default

# Configure root password
echo "root:${ROOT_PASSWORD}" | chpasswd

# Create user
useradd -m -G wheel,audio,video,usb -s /bin/bash ${USERNAME}
echo "${USERNAME}:${ROOT_PASSWORD}" | chpasswd

# Configure sudo
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Configure cryptsetup for boot
echo "root	UUID=$(blkid -s UUID -o value ${LUKS_PART})	none	luks" >> /etc/crypttab

# Update initramfs
emerge --config sys-kernel/gentoo-kernel-bin

# Install and configure GRUB
log_info "Installing GRUB"
emerge --ask=n sys-boot/grub

# For UEFI systems
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Gentoo

# Configure GRUB
echo 'GRUB_CMDLINE_LINUX="crypt_root=UUID=$(blkid -s UUID -o value ${LUKS_PART}) root=/dev/mapper/${LUKS_MAPPER}"' >> /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg

# Enable services
rc-update add sshd default
rc-update add dbus default
rc-update add elogind default

log_success "Chroot installation complete"
EOF

    # Make script executable and run
    chmod +x /mnt/gentoo/root/install.sh
    
    # Export variables for chroot
    export HOSTNAME USERNAME ROOT_PASSWORD LUKS_PASSWORD LUKS_PART LUKS_MAPPER
    
    # Chroot and run installation
    chroot /mnt/gentoo /bin/bash -c "/root/install.sh"
    
    log_success "Chroot installation completed"
}

# Cleanup and final steps
cleanup() {
    log_info "Cleaning up"
    
    # Remove install script
    rm -f /mnt/gentoo/root/install.sh
    
    # Unmount filesystems
    cd /
    umount -l /mnt/gentoo/dev{/shm,/pts,}
    umount -R /mnt/gentoo
    
    # Close LUKS container
    cryptsetup close ${LUKS_MAPPER}
    
    log_success "Cleanup complete"
}

# Main installation function
main() {
    log_info "Starting Gentoo installation"
    
    check_root
    welcome_message
    get_user_input
    setup_disk_vars
    partition_disk
    setup_luks
    create_filesystems
    mount_partitions
    install_stage3
    configure_system
    chroot_install
    cleanup
    
    log_success "Gentoo installation completed successfully!"
    log_info "Reboot and remove installation media"
    log_info "Don't forget to set up your user account and additional software"
}

# Run main function
main "$@"