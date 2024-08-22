#!/bin/bash

# Variables (modify these as needed)
USERNAME="$1"
PASSWORD="$2"
HOSTNAME="gentoo"
ROOT_PASSWORD="$2"  # Change this to your desired root password
STAGE_NAME="stage3-amd64-desktop-systemd-20240818T143401Z.tar.xz"
BINHOST_URL="https://mirror.bytemark.co.uk/gentoo/releases/amd64/binpackages/23.0/x86-64/"  # Replace with your binhost URL
# Check for required arguments
if [ $# -ne 2 ]; then
  echo "Usage: $0 <username> <password>"
  exit 1
fi


# Mount essential filesystems
echo "Mounting essential filesystems..."
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
mount --make-slave /mnt/gentoo/run


# Install Gentoo
echo "Installing Gentoo..."

if [ ! -f "./$STAGE_NAME" ]; then
  echo "Stage3 tarball not found. Downloading..."
  wget wget https://distfiles.gentoo.org/releases/amd64/autobuilds/20240818T143401Z/$STAGE_NAME
fi
echo "Copying tarball"
cp ./$STAGE_NAME /mnt/gentoo/

cd /mnt/gentoo
echo "Extracting the Stage3 tarball"
tar xpfv $STAGE_NAME

echo "# Mount essential filesystems"
mount --rbind /dev /mnt/gentoo/dev
mount --rbind /sys /mnt/gentoo/sys
mount --rbind /proc /mnt/gentoo/proc


# Configure make.conf
echo "chroot and Configure make.conf..."
chroot /mnt/gentoo /bin/bash -c "echo 'FEATURES=\"${FEATURES} binpkg-request-signature binpkg-logs binpkg-multi-instance\"' >> /etc/portage/make.conf"
chroot /mnt/gentoo /bin/bash -c "echo 'BINHOST=\"$BINHOST_URL\"' >> /etc/portage/make.conf"
chroot /mnt/gentoo /bin/bash -c "echo 'MAKEOPTS=\"-j10\"' >> /etc/portage/make.conf"
chroot /mnt/gentoo /bin/bash -c "echo 'ACCEPT_LICENSE=\"*\"' >> /etc/portage/make.conf"
chroot /mnt/gentoo /bin/bash -c "mv /etc/portage/gnupg /etc/portage/gnupg.bak ; getuto"
# Configure binhost in Portage
echo "Configuring binhost..."
cat <<EOF > /mnt/gentoo/etc/portage/binrepos.conf/gentoobinhost.conf
[binhost]
priority = 9999
sync-uri = $BINHOST_URL
EOF




echo "chroot and emerge-webrsync"
# Chroot and install base system
chroot /mnt/gentoo /bin/bash -c "emerge-webrsync && emerge --sync"


echo "selecting plasma systemd profile [28]"
chroot /mnt/gentoo /bin/bash -c "eselect profile set 28" # Set KDE plasma systemd profile
chroot /mnt/gentoo /bin/bash -c "emerge --ask --verbose --update --deep --newuse --getbinpkg @world "



echo "Installing the Linux kernel"
chroot /mnt/gentoo /bin/bash -c "emerge --ask --getbinpkg sys-kernel/gentoo-sources sys-kernel/linux-firmware"
chroot /mnt/gentoo /bin/bash -c "emerge --ask --getbinpkg sys-apps/systemd"
#chroot /mnt/gentoo /bin/bash -c "emerge --ask x11-base/xorg-drivers kde-plasma/plasma-meta"
chroot /mnt/gentoo -c "echo "sys-apps/systemd boot" >> /etc/portage/package.use/systemd"



echo "# Configure systemd-boot"
chroot /mnt/gentoo /bin/bash -c "mkdir -p /usr/lib/systemd/boot/efi"
chroot /mnt/gentoo /bin/bash -c "bootctl --path=/efi install"

chroot /mnt/gentoo /bin/bash -c "cat > /boot/loader/entries/gentoo.conf <<EOF
title   Gentoo Linux
linux   /vmlinuz
initrd  /initramfs
options root=/dev/vdb2 rw
EOF"



echo "Configuring network..."
cp -r /etc/NetworkManager /mnt/gentoo/etc/
chroot /mnt/gentoo /bin/bash -c "systemctl enable NetworkManager"

# Create user and set passwords
chroot /mnt/gentoo /bin/bash -c "useradd -m -G wheel $USERNAME"
echo "$USERNAME:$PASSWORD" | chroot /mnt/gentoo chpasswd
echo "root:$ROOT_PASSWORD" | chroot /mnt/gentoo chpasswd

# Finish up
echo "Installation complete. You can now exit and reboot."

# Unmount partitions
mount -l /mnt/gentoo/dev
mount -l /mnt/gentoo/sys
mount -l /mnt/gentoo/proc

umount -R /mnt/gentoo/boot
umount -R /mnt/gentoo/efi
umount -R /mnt/gentoo
