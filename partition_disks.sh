#!/bin/bash

# Variables (modify these as needed)
DISK="$1"

# Check for required arguments
if [ $# -ne 1 ]; then
  echo "Usage: $0  <disk>"
  exit 1
fi

# Confirm disk selection
echo "You have selected $DISK. All data on this disk will be erased. Proceed? (yes/no)"
read -r CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Aborting."
  exit 1
fi


# Unmount all partitions on the disk
echo "Unmounting any mounted partitions on $DISK..."
umount -l $DISK
for PART in $(lsblk -lnp | grep "$DISK" | awk '{print $1}'); do
  if mountpoint -q "$PART"; then
    echo "Unmounting $PART..."
    umount "$PART"
  fi
done


# Remove filesystem signatures
echo "Removing filesystem signatures from $DISK..."
wipefs -a $DISK



# Remove existing partitions
echo "Removing existing partitions on $DISK..."
(
echo d    # Delete partition
echo 1    # Partition number 1
echo d    # Delete partition
echo 2    # Partition number 2
echo d    # Delete partition
echo 3    # Partition number 3
echo d    # Delete partition
echo 4    # Partition number 4
echo w    # Write changes
) | fdisk $DISK

# Partition the disk
echo "Partitioning disk $DISK..."
(
echo g    # Create a new GPT partition table
echo n    # New partition
echo 1    # Partition number
echo      # Default first sector
echo +512M # Size
echo t    # Change partition type
echo
echo 1    # EFI System Partition (EF00)
echo n    # New partition
echo 2    # Partition number
echo      # Default first sector
echo +15G  # Size
echo n    # New partition
echo 3    # Partition number
echo      # Default first sector
echo +512M # Size
echo t    # Change partition type
echo
echo 3    # Linux filesystem (8300)
echo n    # New partition
echo 4    # Partition number
echo      # Default first sector
echo +2G  # Not  Use the remaining space
echo t    # Change partition type
echo
echo 4    # Linux swap (8200)
echo w    # Write changes
) | fdisk $DISK

# Format the partitions
echo "Formatting partitions..."
mkfs.fat -F32 ${DISK}1     # EFI partition
mkfs.ext4 ${DISK}2         # Root partition
mkfs.ext4 ${DISK}3         # Boot partition
mkswap ${DISK}4            # Swap partition
swapon ${DISK}4            # Enable swap





# Mount the partitions
echo "Mounting partitions..."
mount ${DISK}2 /mnt/gentoo
mkdir -p /mnt/gentoo/boot
mount ${DISK}3 /mnt/gentoo/boot
mkdir -p /mnt/gentoo/efi
mount  ${DISK}1 /mnt/gentoo/efi



# Create fstab file
echo "Creating /etc/fstab file..."
cat <<EOF > /mnt/gentoo/etc/fstab
/dev/vdb1  /efi      vfat    defaults  0  2
/dev/vdb2  /         ext4    defaults  0  1
/dev/vdb3  /boot     ext4    defaults  0  2
/dev/vdb4  none      swap    sw        0  0
EOF
