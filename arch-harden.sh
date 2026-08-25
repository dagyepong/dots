#!/bin/bash

set -euo pipefail

# Hardening Script for Arch Linux / Artix Linux
# Copyright (C) 2019 madaidan
# Copyright (C) 2025-2026 David Uhden Collado
# Refined and enhanced with native systemd-boot support.

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

disable_ntp_system() {
    if [ "$init_system" = "$INIT_SYSTEMD" ]; then
        timedatectl set-ntp 0
    fi
}

# ---- End init system abstraction ----

set_script_options() {
    disable_checks=0
    init_system=""
    use_grub="n"
    use_syslinux="n"
    use_systemd_boot="n"
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "This script must be run as root. Please run with 'sudo'."
        exit 1
    fi
}

update_system() {
    read -r -p "Update the system (pacman -Syu) before hardening? (y/n) " update_system_prompt
    if [ "${update_system_prompt}" = "y" ]; then
        log "Updating the system..."
        pacman -Syu --noconfirm --needed
    fi
}

create_grub_directory() {
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
}

script_checks() {
    detect_init_system
    if ! grep -qE '^(ID=arch|ID=artix)' /etc/os-release 2>/dev/null; then
        error "This script can only be used on Arch Linux or Artix."
        exit 1
    fi

    if [ -d /boot/grub ]; then
        use_grub="y"
        create_grub_directory
    elif [ -d /boot/syslinux ]; then
        use_syslinux="y"
    elif [ -d /boot/loader ]; then
        use_systemd_boot="y"
    else
        error "This script can only be used with GRUB, syslinux, or systemd-boot."
        exit 1
    fi
}

sysctl_hardening() {
    read -r -p "Harden the kernel with sysctl? (y/n) " sysctl_ans
    if [ "${sysctl_ans}" = "y" ]; then
        log "Applying sysctl hardening..."
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
        sysctl --system >/dev/null 2>&1 || true
    fi
}

boot_parameter_hardening() {
    read -r -p "Harden the kernel through boot parameters? (y/n) " bootparams
    if [ "${bootparams}" = "y" ]; then
        local kernel_params="slab_nomerge init_on_alloc=1 init_on_free=1 page_alloc.shuffle=1 pti=on randomize_kstack_offset=on vsyscall=none debugfs=off oops=panic module.sig_enforce=1 lockdown=confidentiality quiet loglevel=0 spectre_v2=on spec_store_bypass_disable=on tsx=off tsx_async_abort=full,nosmt mds=full,nosmt mmio_stale_data=full,nosmt l1tf=full,force nosmt=force kvm.nx_huge_pages=force retbleed=auto,nosmt"

        if [ "${use_grub}" = "y" ]; then
            cat >/etc/default/grub.d/40_kernel_hardening.cfg <<EOF
GRUB_CMDLINE_LINUX="\$GRUB_CMDLINE_LINUX ${kernel_params}"
EOF
            grub-mkconfig -o /boot/grub/grub.cfg
        elif [ "${use_syslinux}" = "y" ]; then
            sed -i '/MENU LABEL Arch Linux/,/^$/ { /APPEND/ s|$| '"${kernel_params}"'| }' /boot/syslinux/syslinux.cfg
        elif [ "${use_systemd_boot}" = "y" ]; then
            # Append parameters to all existing entries in systemd-boot
            for entry in /boot/loader/entries/*.conf; do
                if [ -f "$entry" ] && ! grep -q "slab_nomerge" "$entry"; then
                    sed -i "s|^options \(.*\)$|options \1 ${kernel_params}|" "$entry"
                fi
            done
            bootctl update
        fi
    fi
}

install_linux_hardened() {
    read -r -p "Install linux-hardened? (y/n) " linux_hardened_ans
    if [ "${linux_hardened_ans}" = "y" ]; then
        pacman -S --noconfirm -q linux-hardened linux-hardened-headers

        # Automatically generate a systemd-boot entry if using systemd-boot
        if [ "${use_systemd_boot}" = "y" ]; then
            log "Generating systemd-boot entry for linux-hardened..."
            local stock_entry
            stock_entry=$(ls -t /boot/loader/entries/*.conf | grep -v 'hardened' | head -n 1)
            
            if [ -n "$stock_entry" ] && [ -f "$stock_entry" ]; then
                sed 's/Arch Linux (linux)/Arch Linux (Hardened)/; s|/vmlinuz-linux|/vmlinuz-linux-hardened|; s|/initramfs-linux.img|/initramfs-linux-hardened.img|' "$stock_entry" > /boot/loader/entries/linux-hardened.conf
                log "Successfully created /boot/loader/entries/linux-hardened.conf"
            else
                warn "Could not find a stock entry to clone from. You may need to create /boot/loader/entries/linux-hardened.conf manually."
            fi
        fi
    fi
}

apparmor() {
    read -r -p "Enable apparmor? (y/n) " enable_apparmor
    if [ "${enable_apparmor}" = "y" ]; then
        if ! pacman -Qq apparmor &>/dev/null; then
            pacman -S --noconfirm -q apparmor
        fi
        svc_enable apparmor.service

        local apparmor_params="apparmor=1 security=apparmor audit=1"
        if [ "${use_grub}" = "y" ]; then
            cat >/etc/default/grub.d/40_enable_apparmor.cfg <<EOF
GRUB_CMDLINE_LINUX="\$GRUB_CMDLINE_LINUX ${apparmor_params}"
EOF
            grub-mkconfig -o /boot/grub/grub.cfg
        elif [ "${use_syslinux}" = "y" ]; then
            sed -i '/MENU LABEL Arch Linux/,/^$/ { /APPEND/ s|$| '"${apparmor_params}"'| }' /boot/syslinux/syslinux.cfg
        elif [ "${use_systemd_boot}" = "y" ]; then
            for entry in /boot/loader/entries/*.conf; do
                if [ -f "$entry" ] && ! grep -q "apparmor=1" "$entry"; then
                    sed -i "s|^options \(.*\)$|options \1 ${apparmor_params}|" "$entry"
                fi
            done
            bootctl update
        fi
    fi
}

restrict_root() {
    read -r -p "Restrict su to users in the wheel group? (y/n) " restrict_su
    if [ "${restrict_su}" = "y" ]; then
        sed -i 's/#auth\s\+required\s\+pam_wheel.so use_uid/auth\t\trequired\t\tpam_wheel.so use_uid/' /etc/pam.d/su
        sed -i 's/#auth\s\+required\s\+pam_wheel.so use_uid/auth\t\trequired\t\tpam_wheel.so use_uid/' /etc/pam.d/su-l
    fi
}

firewall() {
    read -r -p "Install and configure nftables firewall? (y/n) " install_nftables
    if [ "${install_nftables}" = "y" ]; then
        if ! pacman -Qq nftables &>/dev/null; then
            pacman -S --noconfirm -q nftables
        fi

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

configure_umask() {
    read -r -p "Set a more restrictive umask? (y/n) " umask_ans
    if [ "${umask_ans}" = "y" ]; then
        echo "umask 0077" >/etc/profile.d/umask.sh
    fi
}

disable_ntp() {
    read -r -p "Disable NTP? (y/n) " ntp
    if [ "${ntp}" = "y" ]; then
        for ntp_client in ntp openntpd ntpclient; do
            if pacman -Qq "${ntp_client}" &>/dev/null; then
                pacman -Rn --noconfirm ${ntp_client}
            fi
        done

        disable_ntp_system
        if [ "$init_system" = "$INIT_SYSTEMD" ]; then
            svc_mask systemd-timesyncd.service
        else
            svc_mask ntpd 2>/dev/null || true
        fi
    fi
}

main() {
    set_script_options
    check_root
    script_checks

    log "Starting hardening script..."
    update_system
    sysctl_hardening
    boot_parameter_hardening
    install_linux_hardened
    apparmor
    firewall
    restrict_root
    configure_umask
    disable_ntp

    log "Hardening script completed successfully!"
}

main "$@"