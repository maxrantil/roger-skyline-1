#!/bin/bash

## Script for auto-installing Artix linux from scratch
## 4 partitions with swap (1G boot)

## FUNCTIONS
###

pacman_candy() { \
		grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
		sed -Ei "s/^#(ParallelDownloads).*/\1 = 5/;/^#Color$/s/#//" /etc/pacman.conf
		}

installpkg() {  \
		pacman -S --noconfirm "$1" >/dev/null 2>&1
		}

## Script Main starts here
###
pacman-key --init
pacman-key --populate

# Make pacman colorful, concurrent downloads and Pacman eye-candy.
pacman_candy

pacman --noconfirm -Sy dialog || error "Are you sure you're running this as the root user, are on an Arch-based distribution and have an internet connection?"
installpkg glibc
installpkg lib32-glibc
dialog --no-cancel --inputbox "Enter a name for your computer(e.g. 'desktop')." 10 60 2> comp
dialog --title "Time Zone select" --yesno "Do you want use zone(Europe/Helsinki)?.\n\nPress no for select your own time zone"  10 60 && echo "Europe/Helsinki" > tz.tmp || tzselect > tz.tmp
dialog --no-cancel --inputbox "Enter partitionsize in gb, separated by space (swap & root)." 10 60 2>psize

IFS=' ' read -ra SIZE <<< $(cat psize)

re='^[0-9]+(\.[0-9]+?)?$'
if ! [ ${#SIZE[@]} -eq 2 ] || ! [[ ${SIZE[0]} =~ $re ]] || ! [[ ${SIZE[1]} =~ $re ]] ; then
    SIZE=(2 4.2);
fi

## for virtualBox /dev/sda
## for virtual manager /dev/vda
## you need to change in chroot.sh where grub is installed too
# disk=$(lsblk | awk '/G/ {print $1}')

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

yes | mkfs.ext4 /dev/sda4
yes | mkfs.ext4 /dev/sda3
yes | mkfs.ext4 /dev/sda1
mkswap /dev/sda2
swapon /dev/sda2
mount /dev/sda3 /mnt
mkdir -p /mnt/boot
mount /dev/sda1 /mnt/boot
mkdir -p /mnt/home
mount /dev/sda4 /mnt/home

rm psize

basestrap /mnt base base-devel runit elogind-runit linux linux-firmware vim

fstabgen -U /mnt >> /mnt/etc/fstab

cat tz.tmp > /mnt/tzfinal.tmp
rm tz.tmp

mv comp /mnt/etc/hostname
hostname=$(</mnt/etc/hostname)
echo -e "127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.0.1\t$hostname.localdomain\t$hostname" >> /mnt/etc/hosts

curl https://raw.githubusercontent.com/maxrantil/roger-skyline-1/master/chroot.sh > /mnt/chroot.sh && artix-chroot /mnt bash chroot.sh && rm /mnt/chroot.sh

umount -R /mnt

dialog --title "Done" --msgbox "After this the computer will poweroff, unmount the .iso file, change the network configuration to Bridged Adapter before starting again"  10 60

poweroff
