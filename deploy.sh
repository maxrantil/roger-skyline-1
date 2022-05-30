#!/bin/bash

# Script for auto-installing Artix linux from scratch
# 4 partitions with swap

dialog --no-cancel --inputbox "Enter a name for your computer." 10 60 2> comp

dialog --defaultno --title "Time Zone select" --yesno "Do you want use zone(Europe/Helsinki)?.\n\nPress no for select your own time zone"  10 60 && echo "Europe/Helsinki" > tz.tmp || tzselect > tz.tmp

dialog --no-cancel --inputbox "Enter partitionsize in gb, separated by space (swap & root)." 10 60 2>psize

IFS=' ' read -ra SIZE <<< $(cat psize)

re='^[0-9]+(\.[0-9]+?)?$'
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

basestrap /mnt base runit elogind-runit linux linux-firmware vim

fstabgen -U /mnt >> /mnt/etc/fstab

cat tz.tmp > /mnt/tzfinal.tmp
rm tz.tmp

mv comp /mnt/etc/hostname

echo "127.0.0.1\tlocalhost\n::1\tlocalhost\n127.0.0.1\t$comp.localdomain $comp" >> /etc/hosts

dialog --no-cancel --inputbox "Enter a name for a user with sudo permissions." 10 60 2> suser
useradd --create-home suser
passwd suser
usermod -aG wheel suser
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

artix-chroot /mnt bash chroot.sh

dialog --defaultno --title "Final Qs" --yesno "Poweroff computer, unmount the .iso file"  5 30 && unmount -R /mnt && poweroff
# dialog --defaultno --title "Final Qs" --yesno "Return to chroot environment?"  6 30 && artix-chroot /mnt
clear
