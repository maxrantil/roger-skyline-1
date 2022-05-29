#!/bin/bash

# 4 partitions with swap

sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk ${TGTDEV}
  n # new partition
  p # primary partition
    # partition number 1
    # default - start at beginning of disk 
  +1G # 1Gb boot parttion
  n # new partition
  p # primary partition
    # partion number 2
    # default, start immediately after preceding partition
  +2.3G # 2.3Gb swap partition
  n # new partition
  p # primary partition
    # partion number 3
    # default, start immediately after preceding partition
  +4.2G # 4.2Gb root parttion
  n # new partition
  p # primary partition
    # partion number 4
    # default, start immediately after preceding partition
    # rest of disk space for last partition
  w # write the partition table
  q # and we're done
EOF

sudo mkfs.ext4 -L BOOT /dev/sda1
sudo mkfs.ext4 -L ROOT /dev/sda3
sudo mkfs.ext4 -L HOME /dev/sda4
sudo mkswap -L SWAP /dev/sda2
sudo swapon /dev/sda2/SWAP
sudo mount /dev/sda3/ROOT /mnt
sudo mkdir /mnt/home
sudo mkdir /mnt/boot
sudo mount /dev/sda1/BOOT /mnt/boot
sudo mount /dev/sda4/HOME /mnt/home


