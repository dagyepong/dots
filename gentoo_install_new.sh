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

# Function to detect available hard drives
detect_disks() {
    log_info "Detecting available hard drives..."
    
    # Get all disk devices (excluding loop, ram, and rom devices)
    DISKS=($(lsblk -d -n -o NAME,TYPE,SIZE,MODEL | grep -E 'disk|nvme' | grep -v -E 'loop|ram|rom' | awk '{print "/dev/" $1}'))
    
    if [ ${#DISKS[@]} -eq 0 ]; then
        log_error "No hard drives detected!"
        exit 1
    fi
    
    log_info "Available hard drives:"
    for i in "${!DISKS[@]}"; do
        SIZE=$(lsblk -d -n -o SIZE "${DISKS[$i]}" | head -1)
        MODEL=$(lsblk -d -n -o MODEL "${DISKS[$i]}" | head -1)
        if [ -z "$MODEL" ] || [ "$MODEL" = " " ]; then
            MODEL="Unknown Model"
        fi
        echo "  $((i+1)). ${DISKS[$i]} - $SIZE - $MODEL"
    done
    
    # Let user select disk
    while true; do
        read -p "Select disk to install Gentoo (1-${#DISKS[@]}): " disk_choice
        
        if [[ $disk_choice =~ ^[0-9]+$ ]] && [ $disk_choice -ge 1 ] && [ $disk_choice -le ${#DISKS[@]} ]; then
            SELECTED_DISK="${DISKS[$((disk_choice-1))]}"
            break
        else
            log_error "Invalid selection. Please enter a number between 1 and ${#DISKS[@]}"
        fi
    done
    
    log_success "Selected disk: $SELECTED_DISK"
    
    # Set partition names based on disk type
    if [[ "$SELECTED_DISK" == *"nvme"* ]]; then
        EFI_PARTITION="${SELECTED_DISK}p1"
        SWAP_PARTITION="${SELECTED_DISK}p2"
        ROOT_PARTITION="${SELECTED_DISK}p3"
    else
        EFI_PARTITION="${SELECTED_DISK}1"
        SWAP_PARTITION="${SELECTED_DISK}2"
        ROOT_PARTITION="${SELECTED_DISK}3"
    fi
    
    export SELECTED_DISK EFI_PARTITION SWAP_PARTITION ROOT_PARTITION
}

# Function to show disk information
show_disk_info() {
    log_info "Detailed information for $SELECTED_DISK:"
    echo
    lsblk "$SELECTED_DISK"
    echo
    parted "$SELECTED_DISK" print
    echo
    
    log_warning "WARNING: All data on $SELECTED_DISK will be destroyed!"
    read -p "Are you sure you want to continue with this disk? (yes/no): " confirm_destroy
    
    if [[ $confirm_destroy != "yes" ]]; then
        log_info "Installation cancelled by user"
        exit 0
    fi
}

# Configuration
MOUNT_POINT="/mnt/gentoo"
TIMEZONE="UTC"
HOSTNAME="gentoo"
KEYMAP="us"
LUKS_NAME="cryptroot"

# User configuration
configure_installation() {
    log_info "Configuration phase"
    
    read -p "Enter hostname [${HOSTNAME}]: " input_hostname
    HOSTNAME=${input_hostname:-$HOSTNAME}
    
    read -p "Enter timezone [${TIMEZONE}]: " input_timezone
    TIMEZONE=${input_timezone:-$TIMEZONE}
    
    read -p "Enter keymap [${KEYMAP}]: " input_keymap
    KEYMAP=${input_keymap:-$KEYMAP}
    
    # Get disk size for swap suggestion
    DISK_SIZE=$(lsblk -d -n -o SIZE "$SELECTED_DISK" | head -1)
    SUGGESTED_SWAP="4G"
    
    read -p "Enter swap size [${SUGGESTED_SWAP}]: " input_swap
    SWAP_SIZE=${input_swap:-$SUGGESTED_SWAP}
    
    read -s -p "Enter LUKS passphrase: " LUKS_PASSWORD
    echo
    read -s -p "Confirm LUKS passphrase: " LUKS_PASSWORD_CONFIRM
    echo
    
    if [ "$LUKS_PASSWORD" != "$LUKS_PASSWORD_CONFIRM" ]; then
        log_error "LUKS passphrases don't match!"
        exit 1
    fi
    
    # Export for use in subshells
    export LUKS_PASSWORD HOSTNAME TIMEZONE KEYMAP SWAP_SIZE
}

# Calculate partition sizes
calculate_partitions() {
    log_info "Calculating partition sizes..."
    
    # Get disk size in bytes
    DISK_BYTES=$(blockdev --getsize64 "$SELECTED_DISK")
    DISK_GB=$((DISK_BYTES / 1024 / 1024 / 1024))
    
    # Convert swap size to megabytes for calculations
    if [[ "$SWAP_SIZE" == *"G" ]]; then
        SWAP_MB=$(( ${SWAP_SIZE%G} * 1024 ))
    elif [[ "$SWAP_SIZE" == *"M" ]]; then
        SWAP_MB=${SWAP_SIZE%M}
    else
        SWAP_MB=4096  # Default to 4GB if no unit specified
    fi
    
    # EFI size (fixed at 512MB)
    EFI_START="1MiB"
    EFI_END="513MiB"
    
    # Swap partition
    SWAP_START="513MiB"
    SWAP_END="$((513 + SWAP_MB))MiB"
    
    # Root partition (rest of disk)
    ROOT_START="$((513 + SWAP_MB))MiB"
    ROOT_END="100%"
    
    export EFI_START EFI_END SWAP_START SWAP_END ROOT_START ROOT_END
    
    log_info "Partition layout:"
    echo "  EFI:  $EFI_START - $EFI_END (512MB)"
    echo "  Swap: $SWAP_START - $SWAP_END ($SWAP_SIZE)"
    echo "  Root: $ROOT_START - $ROOT_END (remaining space)"
}

# Partitioning
partition_disk() {
    log_info "Partitioning disk $SELECTED_DISK"
    
    # Create GPT partition table
    parted -s "$SELECTED_DISK" mklabel gpt
    
    # Create EFI partition
    parted -s "$SELECTED_DISK" mkpart primary fat32 "$EFI_START" "$EFI_END"
    parted -s "$SELECTED_DISK" set 1 esp on
    
    # Create swap partition
    parted -s "$SELECTED_DISK" mkpart primary linux-swap "$SWAP_START" "$SWAP_END"
    
    # Create root partition
    parted -s "$SELECTED_DISK" mkpart primary "$ROOT_START" "$ROOT_END"
    
    # Refresh partition table
    partprobe "$SELECTED_DISK"
    sleep 2
    
    log_success "Disk partitioned successfully"
    
    # Show final partition layout
    log_info "Final partition layout:"
    parted "$SELECTED_DISK" print
}

# Setup encryption
setup_luks() {
    log_info "Setting up LUKS encryption"
    
    # Format root partition with LUKS
    echo "$LUKS_PASSWORD" | cryptsetup luksFormat --type luks2 "$ROOT_PARTITION"
    
    # Open LUKS container
    echo "$LUKS_PASSWORD" | cryptsetup open "$ROOT_PARTITION" "$LUKS_NAME"
    
    LUKS_DEVICE="/dev/mapper/${LUKS_NAME}"
    export LUKS_DEVICE
    
    log_success "LUKS encryption setup completed"
}

# Format partitions
format_partitions() {
    log_info "Formatting partitions"
    
    # Format EFI partition
    mkfs.fat -F 32 "$EFI_PARTITION"
    
    # Format swap
    mkswap "$SWAP_PARTITION"
    swapon "$SWAP_PARTITION"
    
    # Format root partition with XFS
    mkfs.xfs "$LUKS_DEVICE"
    
    log_success "Partitions formatted successfully"
}

# Mount filesystems
mount_filesystems() {
    log_info "Mounting filesystems"
    
    # Mount root
    mount "$LUKS_DEVICE" "$MOUNT_POINT"
    
    # Create and mount EFI directory
    mkdir -p "${MOUNT_POINT}/boot/efi"
    mount "$EFI_PARTITION" "${MOUNT_POINT}/boot/efi"
    
    log_success "Filesystems mounted"
}

# SIMPLIFIED: Direct stage3 download with user input
download_stage3() {
    log_info "Stage3 Download"
    echo
    log_warning "Due to frequent changes in Gentoo's mirror structure, we need to manually get the stage3 URL."
    echo
    log_info "Please follow these steps:"
    echo "1. Open a web browser and go to: https://www.gentoo.org/downloads/"
    echo "2. Find the 'AMD64 OpenRC' version under 'Stage3' section"
    echo "3. Right-click on the download link and copy the URL"
    echo "4. Paste the URL below"
    echo
    log_info "Alternatively, you can try one of these common URLs (replace DATE with current date):"
    echo "https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-openrc/stage3-amd64-openrc-DATE.tar.xz"
    echo "https://ftp.acc.umu.se/mirror/gentoo/releases/amd64/autobuilds/current-stage3-amd64-openrc/stage3-amd64-openrc-DATE.tar.xz"
    echo
    
    while true; do
        read -p "Enter the full stage3 URL: " stage3_url
        
        if [ -z "$stage3_url" ]; then
            log_error "URL cannot be empty"
            continue
        fi
        
        # Basic URL validation
        if [[ "$stage3_url" != *"stage3-amd64-openrc"* ]] || [[ "$stage3_url" != *".tar.xz" ]]; then
            log_warning "URL doesn't look like a stage3 amd64 openrc tarball. Are you sure? (y/n)"
            read -p "Continue anyway? (y/n): " confirm
            if [[ $confirm != "y" && $confirm != "Y" ]]; then
                continue
            fi
        fi
        
        cd "$MOUNT_POINT"
        
        log_info "Downloading: $stage3_url"
        
        # Download with retry logic
        if wget --tries=3 --progress=bar:force "$stage3_url"; then
            # Get the filename from URL
            filename=$(basename "$stage3_url")
            
            # Verify file exists and has reasonable size
            if [ ! -f "$filename" ]; then
                log_error "Downloaded file not found: $filename"
                return 1
            fi
            
            filesize=$(stat -c%s "$filename" 2>/dev/null || stat -f%z "$filename")
            if [ "$filesize" -lt 200000000 ]; then
                log_error "File seems too small ($filesize bytes). Download may have failed."
                rm -f "$filename"
                return 1
            fi
            
            log_info "Extracting stage3 (this may take a while)..."
            if tar xpvf "$filename" --xattrs-include='*.*' --numeric-owner; then
                rm -f "$filename"
                log_success "Stage3 extracted successfully"
                return 0
            else
                log_error "Failed to extract stage3 tarball"
                rm -f "$filename"
                return 1
            fi
        else
            log_error "Failed to download stage3 from: $stage3_url"
            log_info "Please check the URL and try again"
            return 1
        fi
    done
}

# Alternative: Try to find stage3 automatically
try_auto_download() {
    log_info "Attempting to find stage3 automatically..."
    
    cd "$MOUNT_POINT"
    
    # Try to get the current stage3 from a known working mirror
    base_urls=(
        "https://distfiles.gentoo.org/releases/amd64/autobuilds"
        "https://ftp.acc.umu.se/mirror/gentoo/releases/amd64/autobuilds"
    )
    
    for base_url in "${base_urls[@]}"; do
        log_info "Trying: $base_url"
        
        # Try to get the latest stage3 filename
        if wget -q -O latest-stage3.txt "$base_url/latest-stage3-amd64-openrc.txt"; then
            # Parse the file to get the actual stage3 filename
            stage3_path=$(grep -v '^#' latest-stage3.txt | grep -v '^$' | head -1 | awk '{print $1}')
            
            if [ -n "$stage3_path" ]; then
                full_url="$base_url/$stage3_path"
                log_info "Found stage3: $full_url"
                
                if wget --progress=bar:force "$full_url"; then
                    filename=$(basename "$full_url")
                    tar xpvf "$filename" --xattrs-include='*.*' --numeric-owner
                    rm -f "$filename" latest-stage3.txt
                    log_success "Auto-download successful!"
                    return 0
                fi
            fi
            rm -f latest-stage3.txt
        fi
    done
    
    log_warning "Auto-download failed"
    return 1
}

# Configure make.conf
configure_makeconf() {
    log_info "Configuring make.conf"
    
    MAKE_CONF="${MOUNT_POINT}/etc/portage/make.conf"
    
    # Backup original make.conf
    if [ -f "$MAKE_CONF" ]; then
        cp "$MAKE_CONF" "${MAKE_CONF}.backup"
    fi
    
    # Detect CPU cores for parallel compilation
    CPU_CORES=$(nproc)
    MEMORY_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    MEMORY_GB=$((MEMORY_KB / 1024 / 1024))
    
    # Calculate safe job count (don't overload system)
    if [ "$MEMORY_GB" -lt 8 ]; then
        JOBS=$((CPU_CORES / 2))
    else
        JOBS=$CPU_CORES
    fi
    
    # Basic configuration
    cat > "$MAKE_CONF" << EOF
# Common flags
COMMON_FLAGS="-march=native -O2 -pipe"
CFLAGS="\${COMMON_FLAGS}"
CXXFLAGS="\${COMMON_FLAGS}"
FCFLAGS="\${COMMON_FLAGS}"
FFLAGS="\${COMMON_FLAGS}"

# MAKEOPTS - adjust based on your CPU cores and memory
MAKEOPTS="-j${JOBS}"

# Emerge options
EMERGE_DEFAULT_OPTS="--jobs=${JOBS} --load-average=${JOBS}"

# Portage features
FEATURES="buildpkg candy compress-build-logs parallel-fetch userfetch usersync"

# Use binary packages for faster installation
EMERGE_DEFAULT_OPTS="\${EMERGE_DEFAULT_OPTS} --getbinpkg"
FEATURES="\${FEATURES} getbinpkg"

# Binary package host
GENTOO_MIRRORS="https://distfiles.gentoo.org"

# License settings
ACCEPT_LICENSE="*"
EOF

    # Ask user for custom configuration
    echo
    log_warning "Do you want to customize make.conf? (y/n)"
    read -p "Choice: " custom_choice
    
    if [[ $custom_choice == "y" || $custom_choice == "Y" ]]; then
        log_info "Opening make.conf for editing..."
        if command -v nano >/dev/null 2>&1; then
            nano "$MAKE_CONF"
        else
            vi "$MAKE_CONF"
        fi
    fi
    
    log_success "make.conf configured"
}

# Configure basic system
configure_system() {
    log_info "Configuring basic system"
    
    # Copy DNS info
    cp -L /etc/resolv.conf "${MOUNT_POINT}/etc/"
    
    # Mount necessary filesystems
    mount --types proc /proc "${MOUNT_POINT}/proc"
    mount --rbind /sys "${MOUNT_POINT}/sys"
    mount --rbind /dev "${MOUNT_POINT}/dev"
    mount --bind /run "${MOUNT_POINT}/run"
    mount --make-rslave "${MOUNT_POINT}/sys"
    mount --make-rslave "${MOUNT_POINT}/dev"
    
    # Configure fstab
    cat > "${MOUNT_POINT}/etc/fstab" << EOF
# <fs>                  <mountpoint>    <type>    <opts>              <dump/pass>
$LUKS_DEVICE          /               xfs       defaults            0 1
$EFI_PARTITION        /boot/efi       vfat      umask=0077          0 2
$SWAP_PARTITION       none            swap      sw                  0 0
EOF

    log_success "Basic system configured"
}

# Chroot and configure system
chroot_configure() {
    log_info "Chrooting into new system"
    
    # Create chroot script
    cat > "${MOUNT_POINT}/root/chroot_script.sh" << 'EOF'
#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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
log_info "Using kernel version: $KERNEL_VERSION"

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
echo "keymap=\"${KEYMAP}\"" > /etc/conf.d/keymaps

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
    chmod +x "${MOUNT_POINT}/root/chroot_script.sh"
    chroot "$MOUNT_POINT" /bin/bash -c "TIMEZONE='${TIMEZONE}' HOSTNAME='${HOSTNAME}' KEYMAP='${KEYMAP}' ROOT_PARTITION='${ROOT_PARTITION}' LUKS_NAME='${LUKS_NAME}' /root/chroot_script.sh"
    
    # Cleanup chroot script
    rm "${MOUNT_POINT}/root/chroot_script.sh"
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
    echo "1. Exit chroot if still active: exit"
    echo "2. Unmount filesystems: umount -R /mnt/gentoo"
    echo "3. Close LUKS: cryptsetup close cryptroot"
    echo "4. Reboot: reboot"
}

# Finalize installation
finalize_installation() {
    log_info "Finalizing installation"
    
    # Unmount filesystems
    cd /
    umount -l "${MOUNT_POINT}/dev"{/shm,/pts,}
    umount -R "$MOUNT_POINT"
    
    # Close LUKS container
    cryptsetup close "$LUKS_NAME"
    
    # Turn off swap
    swapoff "$SWAP_PARTITION"
    
    show_post_install_tips
}

# Check for necessary tools
check_dependencies() {
    log_info "Checking dependencies..."
    
    local missing_tools=()
    
    for cmd in parted cryptsetup mkfs.fat mkfs.xfs mkswap wget curl lsblk blockdev; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_tools+=("$cmd")
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install them before running this script."
        exit 1
    fi
    
    log_success "All required tools are available"
}

# Main installation process
main() {
    log_info "Starting Gentoo OpenRC installation"
    
    # Check dependencies
    check_dependencies
    
    # Detect and select disk
    detect_disks
    show_disk_info
    
    # Get user configuration
    configure_installation
    calculate_partitions
    
    log_warning "=== FINAL CONFIRMATION ==="
    log_warning "About to install Gentoo on: $SELECTED_DISK"
    log_warning "This will DESTROY ALL DATA on the disk!"
    log_warning "Partition layout:"
    echo "  EFI:  $EFI_PARTITION (512MB)"
    echo "  Swap: $SWAP_PARTITION ($SWAP_SIZE)"
    echo "  Root: $ROOT_PARTITION (LUKS encrypted)"
    echo
    
    read -p "Type 'YES' to continue with installation: " final_confirm
    if [[ $final_confirm != "YES" ]]; then
        log_info "Installation cancelled"
        exit 0
    fi
    
    # Create mount point
    mkdir -p "$MOUNT_POINT"
    
    # Run installation steps
    partition_disk
    setup_luks
    format_partitions
    mount_filesystems
    
    # Try auto download first, then manual if it fails
    if ! try_auto_download; then
        log_warning "Auto-download failed, switching to manual download..."
        download_stage3
    fi
    
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

# Execute main function
main "$@"