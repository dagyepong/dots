#!/bin/bash

# this is a basic script to make my life easier

# exit on error
set -e

# Retry function
run_with_retry() {
  local cmd="$@"
  local max_tries=20
  local delay=10
  local try=0
  until $cmd; do
    try=$((try + 1))
    if [ $try -ge $max_tries ]; then
      echo "Command '$cmd' failed after $max_tries tries" >&2
      return 1
    fi
    echo "Command '$cmd' failed, retrying in $delay seconds..." >&2
    sleep $delay
    delay=$((delay * 2))
  done
}

echo "NOTE: Using installation media via a USB 3.0 port is HIGHLY RECOMMENDED and will result in a far more stable download and installation process."
read -p "Press Enter to start, or type 'bruh' to exit. " pissage
if [ "$pissage" == "bruh" ]; then
  echo "Quitting..."
  exit 1
fi

# Increase pacman timeout to 60 seconds for slow connections
sed -i 's/^#Timeout.*/Timeout = 60/' /etc/pacman.conf

# partitioning
select_partitions() {
  while true; do
    echo "Available disks:"
    lsblk -d -o NAME,SIZE,MODEL
    while true; do
      read -p "Select a disk to partition (e.g., /dev/sda): " disk
      disk_name=$(basename "$disk")
      if lsblk -d -o NAME | grep -q "^$disk_name$"; then
        read -p "Is $disk the correct disk to partition? [y/N] " confirm_disk
        if [[ "$confirm_disk" == "y" || "$confirm_disk" == "Y" ]]; then
          break
        else
          echo "Please select the disk again."
        fi
      else
        echo "Disk $disk does not exist. Please try again."
      fi
    done

    # Prompt for cfdisk
    echo "You will now use cfdisk to partition $disk. This will allow you to create or modify partitions on $disk."
    read -p "Press Enter to start cfdisk, or type 'cancel' to go back to disk selection: " start_cfdisk
    if [ "$start_cfdisk" == "cancel" ]; then
      echo "Cancelling cfdisk. Please select the disk again."
      continue
    fi

    # Run cfdisk
    cfdisk "$disk"

    # TO BE FIXED: does not (always) properly list available partitions
    # List updated partitions
    echo "Partitions on $disk:"
    lsblk -o NAME,SIZE,TYPE,FSTYPE -l $disk

    # Rest of the function remains the same...
    while true; do
      read -p "Enter the root partition for / (e.g., /dev/sda1): " root_part
      root_part_name=$(basename "$root_part")
      if lsblk -o NAME -l $disk | grep -q "^$root_part_name$" && [ "$root_part_name" != "$disk_name" ]; then
        break
      else
        echo "Partition $root_part does not exist on $disk or is the whole disk. Please try again."
      fi
    done
    read -p "Enter the EFI system partition (e.g., /dev/sda2) [optional]: " efi_part
    while [ -n "$efi_part" ]; do
      efi_part_name=$(basename "$efi_part")
      if lsblk -o NAME -l $disk | grep -q "^$efi_part_name$" && [ "$efi_part_name" != "$disk_name" ]; then
        break
      else
        echo "Partition $efi_part does not exist on $disk or is the whole disk. Please try again."
        read -p "Enter the EFI system partition (e.g., /dev/sda2) [optional]: " efi_part
      fi
    done
    read -p "Enter the partition for /home (e.g., /dev/sda3) [optional]: " home_part
    while [ -n "$home_part" ]; do
      home_part_name=$(basename "$home_part")
      if lsblk -o NAME -l $disk | grep -q "^$home_part_name$" && [ "$home_part_name" != "$disk_name" ]; then
        break
      else
        echo "Partition $home_part does not exist on $disk or is the whole disk. Please try again."
        read -p "Enter the partition for /home (e.g., /dev/sda3) [optional]: " home_part
      fi
    done
    echo "Selected partitions:"
    echo "Root: $root_part"
    if [ -n "$efi_part" ]; then
      echo "EFI: $efi_part"
    fi
    if [ -n "$home_part" ]; then
      echo "Home: $home_part"
    fi
    read -p "Is this correct? [y/N] " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
      break
    else
      echo "Please re-enter the partitions."
    fi
  done
}

select_partitions

format_partition() {
  local part=$1    # Partition to format (e.g., /dev/sda3)
  local fs_type=$2 # Filesystem type (e.g., ext4, fat32)
  local label=$3   # Descriptive label (e.g., "root")

  # Check if the partition already has a filesystem
  if blkid "$part" | grep -q "TYPE="; then
    echo "Warning: $label partition $part already has a filesystem."
  else
    echo "No filesystem detected on $label partition $part."
  fi

  # Always prompt for confirmation
  read -p "Do you want to format $label partition $part as $fs_type? This will erase all data on $part. [y/N] " confirm
  if [[ "$confirm" == "y" && "$confirm" == "Y" ]]; then
    echo "You chose not to format the $label partition. The script cannot proceed without formatting. Exiting."
    exit 1
  fi

  # Proceed with formatting based on filesystem type
  case "$fs_type" in
  ext4)
    echo "Formatting $label partition as ext4..."
    mkfs.ext4 -F "$part" || {
      echo "Failed to format $label partition. Exiting."
      exit 1
    }
    ;;
  fat32)
    echo "Formatting $label partition as FAT32..."
    mkfs.fat -F32 "$part" || {
      echo "Failed to format $label partition. Exiting."
      exit 1
    }
    ;;
  *)
    echo "Unsupported filesystem type: $fs_type"
    exit 1
    ;;
  esac

  echo "Successfully formatted $label partition."
}

echo "Formatting partitions..."
format_partition "$root_part" ext4 "root"
format_partition "$efi_part" fat32 "EFI"
if [ -n "$home_part" ]; then
  format_partition "$home_part" ext4 "home"
fi

echo "Mounting partitions..."
# mount partitions & genfstab
mount $root_part /mnt
if [ -n "$efi_part" ]; then
  mkdir -p /mnt/boot
  mount $efi_part /mnt/boot
fi
if [ -n "$home_part" ]; then
  mkdir -p /mnt/home
  mount $home_part /mnt/home
fi
mkdir -p /mnt/etc
genfstab -U /mnt >>/mnt/etc/fstab
findmnt --verify --verbose /mnt/etc/fstab
mountpoint -q /sys/firmware/efi/efivars || mount -t efivarfs efivarfs /sys/firmware/efi/efivars

# system time
timedatectl

# base backages
if ! mountpoint -q /mnt; then
  echo "Error: Root partition not mounted. Aborting."
  exit 1
fi
run_with_retry pacstrap /mnt base base-devel vim nano

# Write install config
echo "efi_part=$efi_part" >/mnt/etc/install-config
echo "root_part=$root_part" >>/mnt/etc/install-config
echo "home_part=$home_part" >>/mnt/etc/install-config

echo "Setting up postinstall and chrooting..."
# Create postinstall script inside chroot
cat >/mnt/root/postinstall.sh <<'POSTINSTALL'
#!/bin/bash
set -e

# Retry function
run_with_retry() {
  local cmd="$@"
  local max_tries=20
  local delay=10
  local try=0
  until $cmd; do
    try=$((try + 1))
    if [ $try -ge $max_tries ]; then
      echo "Command '$cmd' failed after $max_tries tries" >&2
      return 1
    fi
    echo "Command '$cmd' failed, retrying in $delay seconds..." >&2
    sleep $delay
    delay=$((delay * 2))
  done
}

# Increase pacman timeout to 60 seconds for slow connections
sed -i 's/^#Timeout.*/Timeout = 60/' /etc/pacman.conf


# Force interactive shell
if [ ! -t 0 ]; then
  echo "Error: Not running in an interactive terminal. Trying to reattach..."
  exec </dev/tty
fi

source /etc/install-config

# user creation
echo "Prompting for username..."
read -p "What's your user's username? " username
useradd -m "$username"
echo "Setting password for $username..."
passwd "$username"
echo "Setting root password..."
passwd

# Hostname
echo "Prompting for hostname..."
read -p "Enter your desired hostname (default: archlinux): " hostname
echo "${hostname:-archlinux}" > /etc/hostname

# Privileges and user + group management
echo "Adding $username to the following groups: Games, Network, Video, Storage, Optical, Audio & Wheel"
usermod -aG games,network,video,storage,optical,disk,audio,wheel "$username"

# Robust locale and timezone configuration
echo "Setting timezone..."
echo "You can browse available timezones or enter one directly (e.g. America/New_York)."
while true; do
  read -p "Enter a country or city to filter timezones (or press Enter to list all): " filter
  # Build timezone list based on filter
  if [ -z "$filter" ]; then
    timezone_list=$(find /usr/share/zoneinfo -type f -not -path '*/posix/*' -not -path '*/right/*' -not -path '*/Etc/*' | sed 's|^/usr/share/zoneinfo/||' | sort)
  else
    timezone_list=$(find /usr/share/zoneinfo -type f -not -path '*/posix/*' -not -path '*/right/*' -not -path '*/Etc/*' | sed 's|^/usr/share/zoneinfo/||' | grep -i "$filter" | sort)
  fi

  if [ -z "$timezone_list" ]; then
    echo "No timezones found matching '$filter'. Try a different filter."
    continue
  fi

  echo "Available timezones:"
  select timezone in $timezone_list "Enter manually"; do
    if [ "$timezone" = "Enter manually" ]; then
      read -p "Enter timezone manually: " timezone
    fi
    if [ -f "/usr/share/zoneinfo/$timezone" ]; then
      ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime
      echo "Timezone set to $timezone."
      break 2  # Exit both select and while loops
    else
      echo "Invalid timezone: $timezone. Please select a valid option or enter manually."
      break
    fi
  done
done

# Sync hardware clock
if ! timedatectl status | grep -q "System clock synchronized: yes"; then
  hwclock --systohc
  echo "Hardware clock synchronized."
fi

# Locale configuration
echo "Configuring locales..."
configure_locales() {
  while true; do
    while true; do
      read -p "What is your preferred editor? (nano/vim): " editor
      if [ "$editor" = "nano" ] || [ "$editor" = "vim" ]; then
        break
      else
        echo "Invalid choice. Please enter 'nano' or 'vim'."
      fi
    done
    echo "Please uncomment your desired locale(s) in /etc/locale.gen (e.g., en_US.UTF-8)."
    read -p "Press Enter to open the editor..."
    $editor /etc/locale.gen
    if grep -v "^#" /etc/locale.gen | grep -q "[a-z][a-z]_[A-Z][A-Z]\(\.[A-Za-z0-9-]\+\)\?"; then
      echo "Locale(s) selected successfully."
      break
    else
      echo "No valid locales were uncommented in /etc/locale.gen."
      read -p "Would you like to edit it again? [y/N] " retry
      if [[ "$retry" != "y" && "$retry" != "Y" ]]; then
        echo "Error: At least one locale must be uncommented. Exiting."
        exit 1
      fi
    fi
  done
  locale-gen
}

configure_locales

# Add repositories to pacman.conf if not already present
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
  # Check if [multilib] is commented out
  if grep -q "^#\s*\[multilib\]" /etc/pacman.conf; then
    # Uncomment [multilib] and the following Include line
    sed -i '/^#\s*\[multilib\]/,/^#\s*Include =/ s/^#//' /etc/pacman.conf
  else
    # Add [multilib] section
    echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
  fi
fi

if ! grep -q "\[miffe\]" /etc/pacman.conf; then
  echo -e "\n[miffe]\nServer = https://arch.miffe.org/\$arch/" >> /etc/pacman.conf
fi

pacman-key --recv-keys 313F5ABD
pacman-key --finger 313F5ABD
pacman-key --lsign-key 313F5ABD

# Postinstall packages
run_with_retry pacman -Syu --noconfirm
run_with_retry pacman -S git neovim hyprland hypridle ly hyprpicker hyprlock hyprpolkitagent hyprutils hyprpaper sox xdg-desktop-portal-hyprland waybar kitty hyprcursor corectrl fish doas steam mesa pipewire pipewire-jack wireplumber apparmor ufw networkmanager networkmanager-openvpn fastfetch efibootmgr nwg-look mako grim slurp wf-recorder mpv rmpc fuzzel cliphist wofi mpd yazi mangohud bluez bluez-utils mkinitcpio ttf-roboto ttf-roboto-mono ttf-roboto-mono-nerd go qqc2-desktop-style uwsm starship sbctl kbuildsycoca6 gnome-keyring plasma-workspace breeze breeze-icons fcitx kcm-fcitx wofi --noconfirm
run_with_retry pacman -S linux-firmware linux-mainline linux-mainline-headers --noconfirm # installing this last since likely to fail on slower connections

# change shells
chsh -s /usr/bin/fish "$username"
chsh -s /usr/bin/fish root

# Add temporary doas rule to allow passwordless pacman for the wheel group
echo "permit nopass :wheel cmd pacman" > /etc/doas.conf
rm /usr/bin/sudo
ln -s "$(which doas)" /usr/bin/sudo

echo "Building yay as user..."
su -c "bash -c 'cd ~ && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -s --noconfirm'" $username

echo "Installing yay as root..."
pacman -U /home/$username/yay/yay-*.pkg.tar.zst --noconfirm

# Run user-specific commands
echo "Running user-specific commands..."
su -c "bash -c 'export SUDO=doas; cd ~ && rm -rf yay && echo \"Do you have an AMD or NVIDIA GPU?\"; read -p \"Enter 'amd' or 'nvidia': \" GPU_TYPE; echo \$GPU_TYPE > /tmp/gpu_type && if [ \"\$GPU_TYPE\" = \"nvidia\" ]; then yay -S --noconfirm opentabletdriver zen-browser-bin vesktop-bin qt6ct-kde qt5ct-kde vkbasalt python-pywal16 nvidia-open-beta-dkms nvidia-utils-beta nvidia_oc; else yay -S --noconfirm opentabletdriver zen-browser-bin vesktop-bin qt6ct-kde walker-bin vkbasalt python-pywal16 lib32-vulkan-radeon lib32-mesa opencl-mesa; fi && git clone https://git.sr.ht/~_00ein00_/dotfiles && cp -r dotfiles/* /home/$username/.config/ && mkdir -p /home/$username/Pictures/Wallpapers && if [ -d /home/$username/.config/papes ]; then mv /home/$username/.config/papes/* /home/$username/Pictures/Wallpapers/ && rmdir /home/$username/.config/papes; fi'" $username

echo "Switching back to root"
# Read GPU_TYPE from /tmp/gpu_type
GPU_TYPE=$(cat /tmp/gpu_type)
rm /tmp/gpu_type

echo "installing more appropriate packages for GPU considering user input"
if [ "$GPU_TYPE" = "nvidia" ]; then
  pacman -S nvidia-settings nvidia opencl-nvidia lib32-opencl-nvidia libva-nvidia-driver --noconfirm
fi

# replace sudo with doas
echo "permit persist setenv {PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin} :wheel" > /etc/doas.conf
pacman -Rdd sudo --noconfirm
rm /usr/bin/sudo
cat << EOT > /usr/local/bin/sudo-wrapper
#!/bin/sh
# Wrapper to make doas work with makepkg's sudo calls

# Removed flags that doas doesn't support
args=""
for arg in "$@"; do
    case "$arg" in
        -k) ;;  
        *) args="$args $arg" ;;
    esac
done

# Run doas with filtered arguments
exec doas $args
EOT
ln -s /usr/local/bin/sudo-wrapper /usr/bin/sudo
chmod +x /usr/local/bin/sudo-wrapper
chmod +x /usr/bin/sudo

echo "Adding appropriate mkinitcpio modules for GPU selection"
# Configure mkinitcpio.conf modules if not already present
if [ "$GPU_TYPE" = "amd" ]; then
  if ! grep -q "amdgpu" /etc/mkinitcpio.conf; then
    sed -i '/^MODULES=/ s/)$/ amdgpu)/' /etc/mkinitcpio.conf
  fi
elif [ "$GPU_TYPE" = "nvidia" ]; then
  if ! grep -q "nvidia" /etc/mkinitcpio.conf; then
    sed -i '/^MODULES=/ s/)$/ nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
  fi
fi

# Define variables for efibootmgr and kernel-parameters
efi_disk=$(lsblk -no PKNAME "$efi_part")
efi_part_num=$(lsblk -no PARTN "$efi_part")
root_partuuid=$(blkid -s PARTUUID -o value "$root_part")

echo "Configuring kernel-parameters"
# Kernel-parameters and UKI generation
if [ "$GPU_TYPE" = "nvidia" ]; then
  GPU_PARAMS="nvidia-drm.modeset=1"
else
  GPU_PARAMS="amdgpu.ppfeaturemask=0xffffffff"
fi
if ! [ -f /etc/kernel/cmdline ] || ! grep -q "root=UUID=$root_uuid" /etc/kernel/cmdline; then
  echo "root=UUID=$root_partuuid ro rootfstype=ext4 quiet loglevel=3 systemd.show_status=auto rd.udev.log_level=3 lsm=landlock,lockdown,yama,integrity,apparmor,bpf audit=1 audit_backlog_limit=256 $GPU_PARAMS lockdown=integrity" > /etc/kernel/cmdline
fi

# Prompt for EFI boot entry label
echo "Configuring EFI boot entry..."
echo "The EFI boot label is the name that will appear in your computer's UEFI boot menu."
echo "For example, 'Arch Linux' or 'My Arch System'."
read -p "Enter the EFI boot label (default: Arch Linux): " boot_label
boot_label=${boot_label:-Arch Linux}

# last minute bs
sed -i '/^HOOKS=/c\HOOKS=(systemd udev keyboard autodetect microcode modconf block filesystems)' /etc/mkinitcpio.conf
wal -i /home/$username/Pictures/Wallpapers/72189536_p0.png

mkdir -p /boot/EFI/Linux/

# Configure mkinitcpio preset for linux-mainline if not already present
cat << EOT > /etc/mkinitcpio.d/linux-mainline.preset
# mkinitcpio preset file for the 'linux-mainline' package
ALL_kver="/boot/vmlinuz-linux-mainline"
PRESETS=('default' 'fallback')
default_uki="/boot/EFI/Linux/arch-linux-mainline.efi"
default_options="--splash /usr/share/systemd/bootctl/splash-arch.bmp"
fallback_uki="/boot/EFI/Linux/arch-linux-mainline-fallback.efi"
fallback_options="-S autodetect"
EOT

sbctl sign -s /boot/vmlinuz-linux-mainline
sbctl sign -s /boot/efi/Linux/arch-linux-mainline.efi
sbctl sign -s /boot/efi/Linux/arch-linux-mainline-fallback.efi
sbctl sign-all
sbctl verify

# Generate UKI
mkinitcpio -P

# Create EFI boot entry if it doesn’t exist
if ! efibootmgr | grep -q "$boot_label"; then
  efibootmgr --create --disk "/dev/$efi_disk" --part "$efi_part_num" --label "$boot_label" --loader "\EFI\Linux\arch-linux-mainline.efi" --unicode "root=$root_part"
fi

echo "Configuring firewall..."
# Configure firewall
ufw default deny
ufw default deny incoming
ufw default deny routed

# Ensure UFW configuration directory exists
mkdir -p /etc/ufw

# Set default policies in /etc/ufw/user.rules (IPv4)
cat << EOF > /etc/ufw/user.rules
*filter
:ufw-user-input - [0:0]
:ufw-user-output - [0:0]
:ufw-user-forward - [0:0]
-A ufw-user-input -j DROP
-A ufw-user-output -j DROP
-A ufw-user-forward -j DROP
# Allow from 192.168.0.0/24
-A ufw-user-input -s 192.168.0.0/24 -j ACCEPT
# Allow Deluge (assuming ports 6881-6891, adjust as needed)
-A ufw-user-input -p tcp --dport 6881:6891 -j ACCEPT
-A ufw-user-input -p udp --dport 6881:6891 -j ACCEPT
# Limit SSH (port 22)
-A ufw-user-input -p tcp --dport 22 -m state --state NEW -m recent --set
-A ufw-user-input -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 30 --hitcount 6 -j DROP
-A ufw-user-input -p tcp --dport 22 -j ACCEPT
# Allow port 51312
-A ufw-user-input -p tcp --dport 51312 -j ACCEPT
-A ufw-user-input -p udp --dport 51312 -j ACCEPT
# Allow outbound DNS (port 53)
-A ufw-user-output -p udp --dport 53 -j ACCEPT
# Allow outbound HTTP (port 80)
-A ufw-user-output -p tcp --dport 80 -j ACCEPT
# Allow outbound HTTPS (port 443)
-A ufw-user-output -p tcp --dport 443 -j ACCEPT
COMMIT
EOF

# Set default policies in /etc/ufw/user6.rules (IPv6, if needed)
cat << EOF > /etc/ufw/user6.rules
*filter
:ufw6-user-input - [0:0]
:ufw6-user-output - [0:0]
:ufw6-user-forward - [0:0]
-A ufw6-user-input -j DROP
-A ufw6-user-output -j DROP
-A ufw6-user-forward -j DROP
# Allow from 192.168.0.0/24 (IPv6 equivalent, adjust if needed)
-A ufw6-user-input -s fe80::/10 -j ACCEPT
# Allow Deluge (assuming ports 6881-6891)
-A ufw6-user-input -p tcp --dport 6881:6891 -j ACCEPT
-A ufw6-user-input -p udp --dport 6881:6891 -j ACCEPT
# Limit SSH (port 22)
-A ufw6-user-input -p tcp --dport 22 -m state --state NEW -m recent --set
-A ufw6-user-input -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 30 --hitcount 6 -j DROP
-A ufw6-user-input -p tcp --dport 22 -j ACCEPT
# Allow port 51312
-A ufw6-user-input -p tcp --dport 51312 -j ACCEPT
-A ufw6-user-input -p udp --dport 51312 -j ACCEPT
# Allow outbound DNS (port 53)
-A ufw6-user-output -p udp --dport 53 -j ACCEPT
# Allow outbound HTTP (port 80)
-A ufw6-user-output -p tcp --dport 80 -j ACCEPT
# Allow outbound HTTPS (port 443)
-A ufw6-user-output -p tcp --dport 443 -j ACCEPT
COMMIT
EOF

# Enable logging in /etc/ufw/ufw.conf
if ! grep -q "^LOGLEVEL=low" /etc/ufw/ufw.conf; then
  echo "LOGLEVEL=low" >> /etc/ufw/ufw.conf
fi

if ! grep -q "DROP" /etc/ufw/before.rules; then
  sed -i '37s/ACCEPT/DROP/g' /etc/ufw/before.rules
fi
sed -i 's/^ENABLED=.*/ENABLED=yes/' /etc/ufw/ufw.conf || echo "ENABLED=yes" >> /etc/ufw/ufw.conf

# Configure PAM
echo "Configuring PAM for ly"
mkdir -p /etc/pam.d/
cat << EOT > /etc/pam.d/ly
#%PAM-1.0

auth       include      login
account    include      login
password   include      login
session    include      login

auth        include     system-login
-auth       optional    pam_gnome_keyring.so
auth       optional    pam_kwallet5.so

account     include     system-login

password    include     system-login
-password   optional    pam_gnome_keyring.so    use_authtok

-session   optional     pam_systemd.so       class=greeter
-session   optional     pam_elogind.so
session     optional    pam_keyinit.so          force revoke
session     include     system-login
-session    optional    pam_gnome_keyring.so    auto_start
session    optional    pam_kwallet5.so         auto_start
EOT

# Enable system services
systemctl enable ly.service
systemctl enable NetworkManager.service
systemctl --user enable pipewire.service
systemctl --user enable wireplumber.service

echo "Post-installation complete."
rm /root/postinstall.sh
rm /etc/install-config
exit 0
POSTINSTALL

# Make postinstall script executable
chmod +x /mnt/root/postinstall.sh

# Run postinstall inside chroot with forced terminal
arch-chroot /mnt /bin/bash -i /root/postinstall.sh </dev/tty

# Stuff to run after postinstall
echo "Full installation complete!"

while true; do
  read -p "Choose an option:
  - Unmount & Reboot (UR)
  - Unmount & Reboot to Firmware/BIOS (URF)
  - Stay in chroot (CHR)
  - Unmount and stay here (F)
  Enter your choice [UR/URF/CHR/F]: " last_choice

  last_choice=$(echo "$last_choice" | tr '[:lower:]' '[:upper:]')

  if [ "$last_choice" == "UR" ]; then
    echo "unmounting & rebooting..."
    umount /mnt/home /mnt/boot /mnt || echo "Warning: Some unmount operations failed."
    systemctl reboot
    break
  elif [ "$last_choice" == "URF" ]; then
    echo "unmounting and rebooting to firmware..."
    umount /mnt/home /mnt/boot /mnt || echo "Warning: Some unmount operations failed."
    systemctl reboot --firmware
    break
  elif [ "$last_choice" == "CHR" ]; then
    echo "Entering chroot environment. Type 'exit' to return."
    arch-chroot /mnt
    echo "Exited chroot. Please choose another option."
  elif [ "$last_choice" == "F" ]; then
    echo "Unmounting and staying here..."
    umount /mnt/home /mnt/boot /mnt || echo "Warning: Some unmount operations failed."
    exit 0
  else
    echo "That's not a valid answer. Please enter UR, URF, CHR, or F."
  fi
done
