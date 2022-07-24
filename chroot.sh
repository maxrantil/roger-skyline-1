#!/bin/bash

## FUNCTIONS
####

pacman_candy() { \
		grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
		sed -Ei "s/^#(ParallelDownloads).*/\1 = 5/;/^#Color$/s/#//" /etc/pacman.conf
		}

changerootpasswd() { \
spass1=$(dialog --no-cancel --title "Change root password" --passwordbox "Enter a new root password." 10 60 3>&1 1>&2 2>&3 3>&1)
spass2=$(dialog --no-cancel --title "Change root password" --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
while ! [ "$spass1" = "$spass2" ]; do
	unset spass2
	spass1=$(dialog --no-cancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
	spass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
done ;}

installpkg() {  \
		pacman -S --noconfirm "$1" >/dev/null 2>&1
		}

## continue from deploy.sh
###
pacman_candy

TZuser=$(<tzfinal.tmp)
ln -sf /usr/share/zoneinfo/$TZuser /etc/localtime
rm tzfinal.tmp

hwclock --systohc

echo "LANG=en_US.UTF-8" > /etc/locale.conf
sed -i '/#en_US.UTF-8 UTF-8/s/^#//g' /etc/locale.gen
sed -i '/#en_US ISO-8859-1/s/^#//g' /etc/locale.gen
locale-gen

pacman -Sy --noconfirm networkmanager 
installpkg networkmanager-runit
installpkg network-manager-applet
pacman -Sy --noconfirm grub && grub-install --target=i386-pc /dev/sda && grub-mkconfig -o /boot/grub/grub.cfg
installpkg dialog

changerootpasswd
echo -e "$spass1\n$spass1" | passwd

exit
