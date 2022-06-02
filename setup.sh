#!/bin/bash

## FUNCTIONS
####

refreshkeys() {
	dialog --infobox "Enabling Arch Repositories..." 4 40
	pacman --noconfirm --needed -S artix-keyring artix-archlinux-support >/dev/null 2>&1
			for repo in extra community; do
				grep -q "^\[$repo\]" /etc/pacman.conf ||
					echo "[$repo]
Include = /etc/pacman.d/mirrorlist-arch" >> /etc/pacman.conf
			done
			pacman -Sy >/dev/null 2>&1
			pacman-key --populate archlinux >/dev/null 2>&1
;}

## Script Main starts here
####

# Add key-ring
refreshkeys
#echo "Server = https://ftp.ludd.ltu.se/mirrors/artix/$repo/os/$arch" > mirrors
#echo "Server = https://mirrors.dotsrc.org/artix-linux/repos/$repo/os/$arch" >> mirrors
#echo "Server = https://mirror.one.com/artix/$repo/os/$arch" >> mirrors
#echo "Server = https://mirror.clarkson.edu/artix-linux/repos/$repo/os/$arch" >> mirrors
#echo "Server = http://ftp.ntua.gr/pub/linux/artix-linux/$repo/os/$arch" >> mirrors
# Add them to pacman mirrors
#tmp="$(mktemp)" && cat mirrors /etc/pacman.d/mirrorlist >"$tmp" && mv "$tmp" /etc/pacman.d/mirrorlist
#rm mirrors

ln -s /etc/runit/sv/NetworkManager /run/runit/service/NetworkManager
ln -s /etc/runit/sv/sshd /run/runit/service/sshd
ln -s /etc/runit/sv/ufw /run/runit/service/ufw

## create user with sudo permissions
#getuserandpass
#useradd --create-home $name
#echo -e "$pass1\n$pass1" | passwd $name
#usermod -aG wheel $name
#sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL' >> /etc/sudoers


dialog --title "Setup Done" --msgbox "After this the computer will reboot."  10 60
sudo reboot