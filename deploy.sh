#!/bin/bash

## Script for auto-installing Artix linux from scratch
## 4 partitions with swap (1G boot)
###
## FUNCTIONS

getuserandpass() { \ 
        # Prompts user for new username an password.
        name=$(dialog --inputbox "First, please enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1
        while ! echo "$name" | grep -q "^[a-z_][a-z0-9_-]*$"; do
                name=$(dialog --no-cancel --inputbox "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
        done
        pass1=$(dialog --no-cancel --passwordbox "Enter a password for that user." 10 60 3>&1 1>&2 2>&3 3>&1)
        pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
        while ! [ "$pass1" = "$pass2" ]; do
                unset pass2
                pass1=$(dialog --no-cancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
                pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
        done ;}


## Script Main starts here
###

dialog --no-cancel --inputbox "Enter a name for your computer." 10 60 2> comp

dialog --defaultno --title "Time Zone select" --yesno "Do you want use zone(Europe/Helsinki)?.\n\nPress no for select your own time zone"  10 60 && echo "Europe/Helsinki" > tz.tmp || tzselect > tz.tmp
dialog --no-cancel --inputbox "Enter partitionsize in gb, separated by space (swap & root)." 10 60 2>psize

getuserandpass

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

# Make pacman colorful, concurrent downloads and Pacman eye-candy.
grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
sed -Ei "s/^#(ParallelDownloads).*/\1 = 5/;/^#Color$/s/#//" /etc/pacman.conf

basestrap /mnt base runit elogind-runit linux linux-firmware vim

fstabgen -U /mnt >> /mnt/etc/fstab

cat tz.tmp > /mnt/tzfinal.tmp
rm tz.tmp

mv comp /mnt/etc/hostname
hostname=$(</mnt/etc/hostname)
echo -e "127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.0.1\t$hostname.localdomain $hostname" >> /etc/hosts

## create user with sudo permissions
useradd --create-home $name
echo -e "$pass1\n$pass1" | passwd $name

usermod -aG wheel $name
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

curl https://raw.githubusercontent.com/maxrantil/roger-skyline-1/master/chroot.sh > /mnt/chroot.sh && artix-chroot /mnt bash chroot.sh && rm /mnt/chroot.sh

# dialog --title "Done" --msgbox "After this the computer will poweroff, unmount the .iso file and start the VM again."  10 60
umount -R /mnt

# clear
# poweroff
