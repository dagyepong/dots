>Create new GPT table
>
>>Create new GPT partition table using fdisk command.

```python
fdisk /dev/vda
```

**Create encrypted LUKS volume**

```bash
cryptsetup luksFormat /dev/vda2
```

**Open LUKS volume**

```bash
cryptsetup luksOpen /dev/vda2 crypt
```
**Create LVM volume group**

```bash
vgcreate volg /dev/mapper/crypt
```
```bash
lvcreate --name root -L 100G volg
```
```bash
lvcreate --name swap -L 18G volg
```
```bash
lvcreate --name home -l 100%free volg
```

**Format the filesystems**

```bash
mkfs.vfat /dev/vda1
```
```bash
mkfs.xfs /dev/volg/root
```
```bash
mkfs.xfs /dev/volg/home
```
```bash
mkswap /dev/volg/swap
```
```bash
swapon /dev/volg/swap
```

**Mount paritions**

```bash
mount /dev/volg/root /mnt/gentoo
```
```bash
mkdir /mnt/gentoo/{home,boot}
```
```bash
mount /dev/vda1 /mnt/gentoo/boot
```
```bash
mount /dev/volg/home /mnt/gentoo/home
```

**Stage 3 and chroot**

```bash
cd /mnt/gentoo
```
```bash
wget https://distfiles.gentoo.org/releases/amd64/autobuilds/20250115T221822Z/stage3-amd64-systemd-20250115T221822Z.tar.xz
```
```bash
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner -C /mnt/gentoo
```
**Contine with system setup**

**Fetch repo data & keys**

```bash
emerge-webrsync && getuto
```

**LVM & cryptsetup**

```bash

nano /etc/portage/package.use/system
sys-fs/lvm2 lvm
```
```bash
emerge --ask sys-fs/lvm2 sys-fs/cryptsetup
```
```bash
rc-update add lvm boot
```
**Kernel install**

```bash
nano /etc/portage/package.use/system

sys-kernel/installkernel ugrd systemd-boot systemd uki ukify
sys-apps/systemd-utils kernel-install boot ukify
```

```bash
emerge --ask --oneshot installkernel
```

**systemd-boot**

```bash
nano /etc/ugrd/config.toml

modules = [                                                                                                                                                                                                                                                                                                                                                     
  "ugrd.fs.fakeudev",                                                                                                                                                                           
]
```
**Install**

```bash
bootctl install
```
**fstab**

```bash
nano /etc/fstab

UUID=of boot_drive eg vda1 /boot vfat umask=0077 0 2

/dev/volg/root /     xfs defaults,noatime 0 1
/dev/volg/home /home xfs defaults,noatime 0 2

/dev/volg/swap none swap sw 0 0
```

**Kernel**

```bash
touch /etc/kernel/cmdline
```
```bash
emerge --ask gentoo-kernel-bin
```
**Continue installaltion of Firmaware






