### Format Drives
```bash
cryptseup luksFormat /dev/nvme0n1p3
```
Type **YES**
Enetr desired psswrd for luks

### Mount Drives
```bash
cryptsetup luksOpen /dev/nvme0n1p3 root
```
Enetr luks passwd to mount

```bash
mkfs.xfs /dev/mapper/root
```
```bash
mount /dev/mapper/root /mnt/gentoo
```

```bash
cd  /mnt/gentoo
```
```bash
mkdir boot
```
```bash
mount /dev/nvme0n1p1 boot
```
### Dracut Folder
```bash
mkdir -p /etc/dracut.conf.d
```

```bash
nano /etc/dracut.conf.d/luks.conf
```

Paste this:
```bash
add_modules+=" crypt "
kernel_cmdline+=" root=UUID=paste_root_uuid rd.luks.uuid=paste_nvme0n1p3_uuid "
```
Get root UUID from disk:
```bash
lsblk -o name,uuid
```
### USE FLAGS
```bash
nano /etc/portage/package.use/installkernel
```
```py
sys-kernel/installkernel grub dracut
```
### Install Kernel
```bash
emerge -va gentoo-kernel-bin
```

```bash
emerge -va xfsprogs fastfetch
```
