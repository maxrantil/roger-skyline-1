#!/bin/bash

## Script for auto-installing Artix linux from scratch
## 4 partitions with swap (1G boot)

## FUNCTIONS
###


## Script Main starts here
###

pacman --noconfirm --needed -Sy dialog || error "Are you sure you're running this as the root user, are on an Arch-based distribution and have an internet connection?"

dialog --no-cancel --inputbox "Enter a name for your computer(e.g. 'desktop')." 10 60 2> comp
dialog --defaultno --title "Time Zone select" --yesno "Do you want use zone(Europe/Helsinki)?.\n\nPress no for select your own time zone"  10 60 && echo "Europe/Helsinki" > tz.tmp || tzselect > tz.tmp
dialog --no-cancel --inputbox "Enter partitionsize in gb, separated by space (swap & root)." 10 60 2>psize

IFS=' ' read -ra SIZE <<< $(cat psize)

re='^[0-9]+(\.[0-9]+?)?$'
if ! [ ${#SIZE[@]} -eq 2 ] || ! [[ ${SIZE[0]} =~ $re ]] || ! [[ ${SIZE[1]} =~ $re ]] ; then
    SIZE=(12 25);
fi

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

rm psize

# Make pacman colorful, concurrent downloads and Pacman eye-candy.
grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
sed -Ei "s/^#(ParallelDownloads).*/\1 = 5/;/^#Color$/s/#//" /etc/pacman.conf

# Add mirrors
pacman --noconfirm --needed -S artix-keyring artix-archlinux-support >/dev/null 2>&1
			for repo in extra community; do
				grep -q "^\[$repo\]" /etc/pacman.conf ||
					echo "[$repo]
Include = /etc/pacman.d/mirrorlist-arch" >> /etc/pacman.conf
			done
			pacman -Sy >/dev/null 2>&1
			pacman-key --populate archlinux >/dev/null 2>&1
#echo "Server = https://ftp.ludd.ltu.se/mirrors/artix/$repo/os/$arch" > mirrors
#echo "Server = https://mirrors.dotsrc.org/artix-linux/repos/$repo/os/$arch" >> mirrors
#echo "Server = https://mirror.one.com/artix/$repo/os/$arch" >> mirrors
#echo "Server = https://mirror.clarkson.edu/artix-linux/repos/$repo/os/$arch" >> mirrors
#echo "Server = http://ftp.ntua.gr/pub/linux/artix-linux/$repo/os/$arch" >> mirrors
# Add them to pacman mirrors
#tmp="$(mktemp)" && cat mirrors /etc/pacman.d/mirrorlist >"$tmp" && mv "$tmp" /etc/pacman.d/mirrorlist
#rm mirrors

basestrap /mnt base base-devel runit elogind-runit linux linux-firmware vim

fstabgen -U /mnt >> /mnt/etc/fstab

cat tz.tmp > /mnt/tzfinal.tmp
rm tz.tmp

mv comp /mnt/etc/hostname
hostname=$(</mnt/etc/hostname)
echo -e "127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.0.1\t$hostname.localdomain\t$hostname" >> /mnt/etc/hosts

curl https://raw.githubusercontent.com/maxrantil/roger-skyline-1/master/chroot.sh > /mnt/chroot.sh && artix-chroot /mnt bash chroot.sh && rm /mnt/chroot.sh

dialog --title "Done" --msgbox "After this the computer will poweroff, unmount the .iso file and start the VM again."  10 60

umount -R /mnt

clear
poweroff
