#!/bin/bash

## FUNCTIONS
####

changerootpasswd() { \
spass1=$(dialog --no-cancel --title "Change root password" --passwordbox "Enter a new root password." 10 60 3>&1 1>&2 2>&3 3>&1)
spass2=$(dialog --no-cancel --title "Change root password" --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
while ! [ "$spass1" = "$spass2" ]; do
	unset spass2
	spass1=$(dialog --no-cancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
	spass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
done ;}

getuserandpasswd() { \
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

## continue from deploy.sh
###

TZuser=$(cat tzfinal.tmp)
ln -sf /usr/share/zoneinfo/$TZuser /etc/localtime
rm tzfinal.tmp

hwclock --systohc

echo "LANG=en_US.UTF-8" > /etc/locale.conf
#echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8' >> /etc/locale.gen
#echo "en_US ISO-8859-1" >> /etc/locale.gen
sed -i 's/^#en_US ISO-8859-1/en_US ISO-8859-1' >> /etc/locale.gen
locale-gen

pacman -Sy --noconfirm networkmanager networkmanager-runit network-manager-applet

pacman -S --noconfirm grub dialog
grub-install --target=i386-pc /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg

changerootpasswd
echo -e "$spass1\n$spass1" | passwd

getuserandpasswd
useradd --create-home $name
echo -e "$pass1\n$pass1" | passwd $name
usermod -aG wheel $name
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL' >> /etc/sudoers

exit
