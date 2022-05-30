#!/bin/bash

# Script for auto-installing Artix linux from scratch
# 4 partitions with swap

dialog --no-cancel --inputbox "Enter a name for your computer." 10 60 2> comp

dialog --defaultno --title "Time Zone select" --yesno "Do you want use zone(Europe/Helsinki)?.\n\nPress no for select your own time zone"  10 60 && echo "Europe/Helsinki" > tz.tmp || tzselect > tz.tmp

dialog --no-cancel --inputbox "Enter partitionsize in gb, separated by space (swap & root)." 10 60 2>psize

IFS=' ' read -ra SIZE <<< $(cat psize)

re='^[0-9]+$'
if ! [ ${#SIZE[@]} -eq 2 ] || ! [[ ${SIZE[0]} =~ $re ]] || ! [[ ${SIZE[1]} =~ $re ]] ; then
    SIZE=(12 25);
fi

timedatectl set-ntp true

cat <<EOF | fdisk /dev/sda
o
n
p


+1G
n
p


+${SIZE[0]}G
n
p


+${SIZE[1]}G
n
p


w
EOF

yes | mkfs.ext4 /dev/sda1
yes | mkfs.ext4 /dev/sda3
yes | mkfs.ext4 /dev/sda4
mkswap /dev/sda2
swapon /dev/sda2
mount /dev/sda3 /mnt
mkdir -p /mnt/boot
mount /dev/sda1 /mnt/boot
mkdir -p /mnt/home
mount /dev/sda4 /mnt/home
# sudo mkfs.ext4 -L BOOT /dev/sda1
# sudo mkfs.ext4 -L ROOT /dev/sda3
# sudo mkfs.ext4 -L HOME /dev/sda4
# sudo mkswap -L SWAP /dev/sda2
# sudo swapon /dev/sda2/SWAP
# sudo mount /dev/sda3/ROOT /mnt
# sudo mkdir /mnt/home
# sudo mkdir /mnt/boot
# sudo mount /dev/sda1/BOOT /mnt/boot
# sudo mount /dev/sda4/HOME /mnt/home


