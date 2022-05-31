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

# create user with sudo permissions

trap "rm -f psw.txt" 2 15
trap "rm -f psw1.txt" 2 15

for ((i=1; i<=3; i++))
do
        dialog --no-cancel --inputbox "Enter a name for a user with sudo permissions, then choose a password." 10 60 2> user_hold
        dialog --title "Password" --insecure --clear --passwordbox "Please enter password" 10 30 2> pwd.txt
        dialog --title "Confirm Password" --insecure --clear --passwordbox "Please enter password" 10 30 2> pwd1.txt
        var=$(cat pwd.txt)
        var1=$(cat pwd1.txt)
        if [ $var == $var1 ]
        then
                break
        fi
done

suser=$(<user_hold)
useradd --create-home $suser
passwd $suser
echo $var
echo $var

rm pwd.txt 
rm pwd1.txt 

usermod -aG wheel $suser
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
rm user_hold

mv chroot.sh /mnt/chroot.sh && artix-chroot /mnt bash chroot.sh && rm /mnt/chroot.sh

dialog --title "Done" --msgbox "After this the computer will poweroff, unmount the .iso file and start the VM again."  10 60
unmount -R /mnt
poweroff

clear
