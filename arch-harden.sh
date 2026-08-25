#!/bin/bash

set -euo pipefail

# Hardening Script for Arch Linux / Artix Linux
# Refined and modernized version.

log() { printf '%s [INFO] [OK] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
warn() { printf '%s [WARN] [WARN] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; }
error() { printf '%s [ERROR] [ERROR] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; }

# ---- Init system detection and service management ----

INIT_SYSTEMD="systemd"
INIT_OPENRC="openrc"
INIT_RUNIT="runit"
INIT_S6="s6"
INIT_DINIT="dinit"

detect_init_system() {
    if [ -d /run/systemd/system ] || systemctl >/dev/null 2>&1; then
        init_system="$INIT_SYSTEMD"
    elif [ -d /run/openrc ] || rc-status >/dev/null 2>&1; then
        init_system="$INIT_OPENRC"
    elif [ -d /run/runit ] || [ -d /etc/runit ]; then
        init_system="$INIT_RUNIT"
    elif pidof s6-svscan >/dev/null 2>&1 || [ -d /etc/s6 ]; then
        init_system="$INIT_S6"
    elif command -v dinit >/dev/null 2>&1 || [ -d /etc/dinit.d ]; then
        init_system="$INIT_DINIT"
    else
        init_system="unknown"
    fi
}

svc_enable() {
    local svc="$1"
    case "$init_system" in
    "$INIT_SYSTEMD") systemctl enable "$svc" ;;
    "$INIT_OPENRC") rc-update add "$svc" default ;;
    "$INIT_RUNIT")
        [ -d "/run/runit/service" ] && ln -sf "/etc/runit/sv/$svc" "/run/runit/service/$svc" 2>/dev/null
        [ -d "/var/service" ] && ln -sf "/etc/sv/$svc" "/var/service/$svc" 2>/dev/null
        ;;
    "$INIT_S6") s6-rc-bundle add default "$svc" 2>/dev/null || true ;;
    "$INIT_DINIT") dinitctl enable "$svc" 2>/dev/null || true ;;
    *) warn "Unknown init system: cannot enable $svc" ;;
    esac
}

svc_enable_now() {
    local svc="$1"
    case "$init_system" in
    "$INIT_SYSTEMD") systemctl enable --now "$svc" ;;
    "$INIT_OPENRC") rc-update add "$svc" default && rc-service "$svc" start ;;
    "$INIT_RUNIT")
        svc_enable "$svc"
        sv start "$svc" 2>/dev/null || true
        ;;
    "$INIT_S6")
        s6-rc-bundle add default "$svc" 2>/dev/null
        s6-rc -u change "$svc" 2>/dev/null || true
        ;;
    "$INIT_DINIT") dinitctl enable "$svc" 2>/dev/null && dinitctl start "$svc" 2>/dev/null || true ;;
    *) warn "Unknown init system: cannot enable/start $svc" ;;
    esac
}

svc_mask() {
    local svc="$1"
    case "$init_system" in
    "$INIT_SYSTEMD") systemctl mask "$svc" ;;
    "$INIT_OPENRC")
        rc-service "$svc" stop 2>/dev/null
        rc-update del "$svc" 2>/dev/null || true
        ;;
    "$INIT_RUNIT")
        sv stop "$svc" 2>/dev/null
        rm -f "/run/runit/service/$svc" "/var/service/$svc" 2>/dev/null
        ;;
    "$INIT_S6")
        s6-rc -d change "$svc" 2>/dev/null
        s6-rc-bundle delete default "$svc" 2>/dev/null || true
        ;;
    "$INIT_DINIT")
        dinitctl stop "$svc" 2>/dev/null
        dinitctl disable "$svc" 2>/dev/null || true
        ;;
    *) warn "Cannot mask service '$svc' on $init_system; best-effort disable" ;;
    esac
}

set_hostname_cmd() {
    local name="$1"
    if [ "$init_system" = "$INIT_SYSTEMD" ]; then
        hostnamectl set-hostname "$name"
    else
        echo "$name" >/etc/hostname
        command -v hostname >/dev/null 2>&1 && hostname "$name" || true
    fi
}

disable_ntp_system() {
    if [ "$init_system" = "$INIT_SYSTEMD" ]; then
        timedatectl set-ntp 0
    fi
}

# ---- Script options & validation ----

set_script_options() {
    disable_checks=0
    init_system=""
    use_grub="n"
    use_syslinux="n"
    use_systemd_boot="n"
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "This script must be run as root. Use 'sudo'."
        exit 1
    fi
}

script_checks() {
    detect_init_system
    if ! grep -qE '^(ID=arch|ID=artix)' /etc/os-release 2>/dev/null; then
        error "This script can only be used on Arch Linux or Artix."
        exit 1
    fi

    if [ -d /boot/grub ]; then
        use_grub="y"
        if ! [ -d /etc/default/grub.d ]; then
            mkdir -m 755 /etc/default/grub.d
        fi
        if ! grep -qF '/etc/default/grub.d/*.cfg' /etc/default/grub 2>/dev/null; then
            cat >>/etc/default/grub <<'EOF'
for i in /etc/default/grub.d/*.cfg ; do
if [ -e "${i}" ]; then
    . "${i}"
fi
done
EOF
        fi
    elif [ -d /boot/syslinux ]; then
        use_syslinux="y"
    elif [ -d /boot/loader ]; then
        use_systemd_boot="y"
    else
        error "Supported bootloader (GRUB, syslinux, systemd-boot) not detected."
        exit 1
    fi
}

# ---- Hardening Modules ----

update_system() {
    read -r -p "Update the system (pacman -Syu) before hardening? (y/n) " ans
    if [ "$ans" = "y" ]; then
        pacman -Syu --noconfirm --needed
    fi
}

sysctl_hardening() {
    read -r -p "Harden the kernel with sysctl? (y/n) " ans
    if [ "$ans" = "y" ]; then
        log "Applying sysctl hardening rules..."
        echo "kernel.kptr_restrict=2" >/etc/sysctl.d/kptr_restrict.conf
        echo "kernel.dmesg_restrict=1" >/etc/sysctl.d/dmesg_restrict.conf
        echo "kernel.printk=3 3 3 3" >/etc/sysctl.d/printk.conf
        echo "kernel.unprivileged_bpf_disabled=1\nnet.core.bpf_jit_harden=2" >/etc/sysctl.d/harden_bpf.conf
        echo "dev.tty.ldisc_autoload=0" >/etc/sysctl.d/ldisc_autoload.conf
        echo "vm.unprivileged_userfaultfd=0" >/etc/sysctl.d/userfaultfd.conf
        echo "kernel.kexec_load_disabled=1" >/etc/sysctl.d/kexec.conf
        echo "kernel.sysrq=4" >/etc/sysctl.d/sysrq.conf
        echo "kernel.perf_event_paranoid=3" >/etc/sysctl.d/perf_event.conf
        echo "kernel.yama.ptrace_scope=2" >/etc/sysctl.d/ptrace_scope.conf
        echo "vm.mmap_rnd_bits=32\nvm.mmap_rnd_compat_bits=16" >/etc/sysctl.d/mmap_aslr.conf
        echo "fs.protected_symlinks=1\nfs.protected_hardlinks=1" >/etc/sysctl.d/protected_links.conf
        echo "fs.protected_fifos=2\nfs.protected_regular=2" >/etc/sysctl.d/protected_files.conf
        
        # NOTE: Unprivileged user namespaces are commented out by default because 
        # they break containers (Docker/Podman), Flatpak, and browser sandboxes.
        # Uncomment below if you are building a strict server environment:
        # echo "kernel.unprivileged_userns_clone=0" >/etc/sysctl.d/unprivileged_userns.conf

        sysctl --system >/dev/null 2>&1 || true
    fi
}

boot_parameter_hardening() {
    read -r -p "Harden the kernel through boot parameters? (y/n) " ans
    if [ "$ans" = "y" ]; then
        local kernel_params="slab_nomerge init_on_alloc=1 init_on_free=1 page_alloc.shuffle=1 pti=on randomize_kstack_offset=on vsyscall=none debugfs=off oops=panic module.sig_enforce=1 lockdown=confidentiality quiet loglevel=0 spectre_v2=on spec_store_bypass_disable=on tsx=off tsx_async_abort=full,nosmt mds=full,nosmt mmio_stale_data=full,nosmt l1tf=full,force nosmt=force kvm.nx_huge_pages=force retbleed=auto,nosmt"

        if [ "$use_grub" = "y" ]; then
            cat >/etc/default/grub.d/40_kernel_hardening.cfg <<EOF
GRUB_CMDLINE_LINUX="\$GRUB_CMDLINE_LINUX ${kernel_params}"
EOF
            grub-mkconfig -o /boot/grub/grub.cfg
        elif [ "$use_syslinux" = "y" ]; then
            sed -i '/MENU LABEL Arch Linux/,/^$/ { /APPEND/ s|$| '"${kernel_params}"'| }' /boot/syslinux/syslinux.cfg
        elif [ "$use_systemd_boot" = "y" ]; then
            sed -i "s|^options .*|& ${kernel_params}|" /boot/loader/entries/*.conf
            bootctl update
        fi
    fi
}

install_linux_hardened() {
    read -r -p "Install linux-hardened kernel? (y/n) " ans
    if [ "$ans" = "y" ]; then
        pacman -S --noconfirm -q linux-hardened linux-hardened-headers
        # (Bootloader entry configuration omitted for brevity; use standard Arch guides if needed)
    fi
}

apparmor() {
    read -r -p "Enable AppArmor? (y/n) " ans
    if [ "$ans" = "y" ]; then
        if ! pacman -Qq apparmor &>/dev/null; then
            pacman -S --noconfirm -q apparmor
        fi
        svc_enable apparmor.service
        
        local apparmor_params="apparmor=1 security=apparmor audit=1"
        if [ "$use_grub" = "y" ]; then
            cat >/etc/default/grub.d/40_enable_apparmor.cfg <<EOF
GRUB_CMDLINE_LINUX="\$GRUB_CMDLINE_LINUX ${apparmor_params}"
EOF
            grub-mkconfig -o /boot/grub/grub.cfg
        elif [ "$use_syslinux" = "y" ]; then
            sed -i '/MENU LABEL Arch Linux/,/^$/ { /APPEND/ s|$| '"${apparmor_params}"'| }' /boot/syslinux/syslinux.cfg
        elif [ "$use_systemd_boot" = "y" ]; then
            sed -i "s|^options .*|& ${apparmor_params}|" /boot/loader/entries/*.conf
            bootctl update
        fi
    fi
}

firewall() {
    read -r -p "Install and configure nftables firewall? (y/n) " ans
    if [ "$ans" = "y" ]; then
        if ! pacman -Qq nftables &>/dev/null; then
            pacman -S --noconfirm -q nftables
        }
        cat <<'NFTEOF' >/etc/nftables.conf
#!/usr/bin/nft -f
flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        ct state established,related accept
        ct state invalid drop
        iif lo accept
        ip protocol icmp accept
        ip6 nexthdr ipv6-icmp accept
    }
    chain forward {
        type filter hook forward priority 0; policy drop;
    }
    chain output {
        type filter hook output priority 0; policy accept;
    }
}
NFTEOF
        svc_enable_now nftables.service
    fi
}

restrict_root() {
    read -r -p "Restrict su to users in the wheel group? (y/n) " ans
    if [ "$ans" = "y" ]; then
        sed -i 's/#auth\s\+required\s\+pam_wheel.so use_uid/auth\t\trequired\t\tpam_wheel.so use_uid/' /etc/pam.d/su
        sed -i 's/#auth\s\+required\s\+pam_wheel.so use_uid/auth\t\trequired\t\tpam_wheel.so use_uid/' /etc/pam.d/su-l
    fi
}

configure_umask() {
    read -r -p "Set a more restrictive umask (0077)? (y/n) " ans
    if [ "$ans" = "y" ]; then
        echo "umask 0077" >/etc/profile.d/umask.sh
    fi
}

# ---- Main Execution ----

main() {
    check_root
    script_checks

    log "Starting interactive Arch hardening..."
    update_system
    sysctl_hardening
    boot_parameter_hardening
    install_linux_hardened
    apparmor
    firewall
    restrict_root
    configure_umask

    log "Hardening process completed successfully!"
}

main "$@"