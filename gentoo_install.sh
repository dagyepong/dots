#!/bin/bash

# Gentoo OpenRC Installation Script
# For LUKS encrypted system with XFS and EFI
# Uses gentoo-kernel-bin for faster installation
# Usage: ./gentoo_install.sh

set -e

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

# Configuration
DEVICE="/dev/nvme0n1"
EFI_PARTITION="${DEVICE}p1"
SWAP_PARTITION="${DEVICE}p2"
ROOT_PARTITION="${DEVICE}p3"
LUKS_NAME="cryptroot"
LUKS_DEVICE="/dev/mapper/${LUKS_NAME}"
MOUNT_POINT="/mnt/gentoo"
TIMEZONE="UTC"
HOSTNAME="gentoo"
KEYMAP="us"

# User configuration
configure_installation() {
    log_info "Configuration phase"
    
    read -p "Enter hostname [${HOSTNAME}]: " input_hostname
    HOSTNAME=${input_hostname:-$HOSTNAME}
    
    read -p "Enter timezone [${TIMEZONE}]: " input_timezone
    TIMEZONE=${input_timezone:-$TIMEZONE}
    
    read -p "Enter keymap [${KEYMAP}]: " input_keymap
    KEYMAP=${input_keymap:-$KEYMAP}
    
    read -s -p "Enter LUKS passphrase: " LUKS_PASSWORD
    echo
    read -s -p "Confirm LUKS passphrase: " LUKS_PASSWORD_CONFIRM
    echo
    
    if [ "$LUKS_PASSWORD" != "$LUKS_PASSWORD_CONFIRM" ]; then
        log_error "LUKS passphrases don't match!"
        exit 1
    fi
    
    # Export for use in subshells
    export LUKS_PASSWORD
}

# Partitioning
partition_disk() {
    log_info "Partitioning disk ${DEVICE}"
    
    # Create GPT partition table
    parted -s ${DEVICE} mklabel gpt
    
    # Create EFI partition (512MB)
    parted -s ${DEVICE} mkpart primary fat32 1MiB 513MiB
    parted -s ${DEVICE} set 1 esp on
    
    # Create swap partition (4GB)
    parted -s ${DEVICE} mkpart primary linux-swap 513MiB 4609MiB
    
    # Create root partition (remaining space)
    parted -s ${DEVICE} mkpart primary 4609MiB 100%
    
    log_success "Disk partitioned successfully"
}

# Setup encryption
setup_luks() {
    log_info "Setting up LUKS encryption"
    
    # Format root partition with LUKS
    echo "$LUKS_PASSWORD" | cryptsetup luksFormat --type luks2 ${ROOT_PARTITION}
    
    # Open LUKS container
    echo "$LUKS_PASSWORD" | cryptsetup open ${ROOT_PARTITION} ${LUKS_NAME}
    
    log_success "LUKS encryption setup completed"
}

# Format partitions
format_partitions() {
    log_info "Formatting partitions"
    
    # Format EFI partition
    mkfs.fat -F 32 ${EFI_PARTITION}
    
    # Format swap
    mkswap ${SWAP_PARTITION}
    swapon ${SWAP_PARTITION}
    
    # Format root partition with XFS
    mkfs.xfs ${LUKS_DEVICE}
    
    log_success "Partitions formatted successfully"
}

# Mount filesystems
mount_filesystems() {
    log_info "Mounting filesystems"
    
    # Mount root
    mount ${LUKS_DEVICE} ${MOUNT_POINT}
    
    # Create and mount EFI directory
    mkdir -p ${MOUNT_POINT}/boot/efi
    mount ${EFI_PARTITION} ${MOUNT_POINT}/boot/efi
    
    log_success "Filesystems mounted"
}

# Download and extract stage3
download_stage3() {
    log_info "Downloading Gentoo stage3"
    
    cd ${MOUNT_POINT}
    
    # Get latest stage3 openrc amd64
    STAGE3_URL=$(curl -s https://www.gentoo.org/downloads/ | grep -oP 'https://.*stage3-amd64-openrc-[0-9]{8}T[0-9]{6}Z.tar.xz' | head -1)
    
    if [ -z "$STAGE3_URL" ]; then
        log_error "Could not find stage3 download URL"
        exit 1
    fi
    
    wget $STAGE3_URL
    STAGE3_FILE=$(basename $STAGE3_URL)
    
    log_info "Extracting stage3"
    tar xpvf $STAGE3_FILE --xattrs-include='*.*' --numeric-owner
    
    log_success "Stage3 downloaded and extracted"
}

# Configure make.conf
configure_makeconf() {
    log_info "Configuring make.conf"
    
    MAKE_CONF="${MOUNT_POINT}/etc/portage/make.conf"
    
    # Backup original make.conf
    cp ${MAKE_CONF} ${MAKE_CONF}.backup
    
    # Basic configuration
    cat > ${MAKE_CONF} << 'EOF'
# Common flags
COMMON_FLAGS="-march=native -O2 -pipe"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
FCFLAGS="${COMMON_FLAGS}"
FFLAGS="${COMMON_FLAGS}"

# MAKEOPTS - adjust based on your CPU cores
MAKEOPTS="-j$(nproc)"

# Emerge options
EMERGE_DEFAULT_OPTS="--jobs=$(nproc) --load-average=$(nproc)"

# Portage features
FEATURES="buildpkg candy compress-build-logs parallel-fetch userfetch usersync"

# Use binary packages for faster installation
EMERGE_DEFAULT_OPTS="${EMERGE_DEFAULT_OPTS} --getbinpkg"
FEATURES="${FEATURES} getbinpkg"

# Binary package host (adjust mirror as needed)
GENTOO_MIRRORS="https://distfiles.gentoo.org"
EOF

    # Ask user for custom configuration
    echo
    log_warning "Do you want to customize make.conf? (y/n)"
    read -p "Choice: " custom_choice
    
    if [[ $custom_choice == "y" || $custom_choice == "Y" ]]; then
        log_info "Opening make.conf for editing..."
        nano ${MAKE_CONF}
    fi
    
    log_success "make.conf configured"
}

# Configure basic system
configure_system() {
    log_info "Configuring basic system"
    
    # Copy DNS info
    cp -L /etc/resolv.conf ${MOUNT_POINT}/etc/
    
    # Mount necessary filesystems
    mount --types proc /proc ${MOUNT_POINT}/proc
    mount --rbind /sys ${MOUNT_POINT}/sys
    mount --rbind /dev ${MOUNT_POINT}/dev
    mount --bind /run ${MOUNT_POINT}/run
    mount --make-rslave ${MOUNT_POINT}/sys
    mount --make-rslave ${MOUNT_POINT}/dev
    
    # Configure fstab
    cat > ${MOUNT_POINT}/etc/fstab << EOF
# <fs>                  <mountpoint>    <type>    <opts>              <dump/pass>
${LUKS_DEVICE}          /               xfs       defaults            0 1
${EFI_PARTITION}        /boot/efi       vfat      umask=0077          0 2
${SWAP_PARTITION}       none            swap      sw                  0 0
EOF

    log_success "Basic system configured"
}

# Chroot and configure system
chroot_configure() {
    log_info "Chrooting into new system"
    
    # Create chroot script
    cat > ${MOUNT_POINT}/root/chroot_script.sh << 'EOF'
#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Configure timezone
log_info "Configuring timezone"
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime

# Configure locale
log_info "Configuring locale"
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
eselect locale set en_US.utf8

# Update environment
env-update && source /etc/profile

# Sync portage
log_info "Syncing Portage tree"
emerge --sync

# Install gentoo-kernel-bin (pre-compiled kernel)
log_info "Installing gentoo-kernel-bin"
emerge --ask --verbose sys-kernel/gentoo-kernel-bin

# Install necessary tools
log_info "Installing necessary system tools"
emerge --ask --verbose \
    sys-boot/grub \
    sys-fs/cryptsetup \
    net-misc/dhcpcd \
    app-editors/nano \
    sys-apps/pciutils

# Generate initramfs with LUKS support
log_info "Generating initramfs with LUKS support"
emerge --ask --verbose sys-kernel/genkernel

# Create genkernel configuration for LUKS
cat > /etc/genkernel.conf << 'GENKERNEL'
LUKS="yes"
LUKS_KEY="/crypto_keyfile.bin"
LVM="no"
MDADM="no"
DMRAID="no"
BUSYBOX="yes"
GENKERNEL

# Get kernel version from gentoo-kernel-bin
KERNEL_VERSION=$(ls /lib/modules | head -n1)

# Generate initramfs for the installed kernel
genkernel --luks --kerneldir=/usr/src/linux --kernel-config=/usr/src/linux/.config initramfs

# Install and configure bootloader
log_info "Installing and configuring GRUB"

# Mount EFI partition
mount /boot/efi

# Get root partition UUID
ROOT_UUID=$(blkid -s UUID -o value ${ROOT_PARTITION})

# Configure GRUB for LUKS
cat >> /etc/default/grub << GRUB_CONFIG

# LUKS encryption
GRUB_CMDLINE_LINUX="crypt_root=UUID=${ROOT_UUID} root=/dev/mapper/${LUKS_NAME}"
GRUB_ENABLE_CRYPTODISK=y
GRUB_CONFIG

# Install GRUB
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=gentoo
grub-mkconfig -o /boot/grub/grub.cfg

# Set root password
log_info "Setting root password"
passwd

# Enable services
log_info "Enabling services"
rc-update add sshd default
rc-update add dhcpcd default

# Configure keymap
log_info "Configuring keymap"
echo 'keymap="${KEYMAP}"' > /etc/conf.d/keymaps

# Configure hostname
echo "hostname=\"${HOSTNAME}\"" > /etc/conf.d/hostname

# Install additional useful packages
log_info "Installing additional useful packages"
emerge --ask --verbose \
    sys-apps/usbutils \
    sys-process/htop \
    net-misc/curl \
    app-misc/tmux \
    sys-fs/e2fsprogs

# Cleanup
umount /boot/efi

log_success "Chroot configuration completed"
EOF

    # Make script executable and run
    chmod +x ${MOUNT_POINT}/root/chroot_script.sh
    chroot ${MOUNT_POINT} /bin/bash -c "TIMEZONE='${TIMEZONE}' HOSTNAME='${HOSTNAME}' KEYMAP='${KEYMAP}' ROOT_PARTITION='${ROOT_PARTITION}' LUKS_NAME='${LUKS_NAME}' /root/chroot_script.sh"
    
    # Cleanup chroot script
    rm ${MOUNT_POINT}/root/chroot_script.sh
}

# Post-installation tips
show_post_install_tips() {
    log_success "Installation completed successfully!"
    echo
    log_warning "Important post-installation steps:"
    echo "1. Review your network configuration in /etc/conf.d/net"
    echo "2. Configure any additional services you need"
    echo "3. Update your system regularly: emerge --sync && emerge -uDN @world"
    echo "4. Read the Gentoo Handbook for further customization"
    echo
    log_warning "To reboot into your new system:"
    echo "1. Exit chroot: exit"
    echo "2. Unmount filesystems: umount -R /mnt/gentoo"
    echo "3. Close LUKS: cryptsetup close cryptroot"
    echo "4. Reboot: reboot"
}

# Finalize installation
finalize_installation() {
    log_info "Finalizing installation"
    
    # Unmount filesystems
    cd /
    umount -l ${MOUNT_POINT}/dev{/shm,/pts,}
    umount -R ${MOUNT_POINT}
    
    # Close LUKS container
    cryptsetup close ${LUKS_NAME}
    
    # Turn off swap
    swapoff ${SWAP_PARTITION}
    
    show_post_install_tips
}

# Main installation process
main() {
    log_info "Starting Gentoo OpenRC installation"
    log_warning "This script will erase all data on ${DEVICE}"
    log_warning "Make sure you have backups!"
    
    read -p "Continue with installation? (y/n): " confirm
    if [[ $confirm != "y" && $confirm != "Y" ]]; then
        log_info "Installation cancelled"
        exit 0
    fi
    
    # Create mount point
    mkdir -p ${MOUNT_POINT}
    
    # Run installation steps
    configure_installation
    partition_disk
    setup_luks
    format_partitions
    mount_filesystems
    download_stage3
    configure_makeconf
    configure_system
    chroot_configure
    finalize_installation
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
fi

# Check if device exists
if [[ ! -e ${DEVICE} ]]; then
    log_error "Device ${DEVICE} does not exist"
    exit 1
fi

# Check for necessary tools
for cmd in parted cryptsetup mkfs.fat mkfs.xfs mkswap wget curl; do
    if ! command -v $cmd &> /dev/null; then
        log_error "Required command '$cmd' not found. Please install it first."
        exit 1
    fi
done

# Execute main function
main "$@"