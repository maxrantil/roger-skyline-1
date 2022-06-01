#!/bin/bash

## FUNCTIONS
####

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
####

# Add key-ring
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

pacman -S --noconfirm sudo openssh-runit openssh

ln -s  /etc/runit/sv/NetworkManager /run/runit/service/NetworkManager
ln -s  /etc/runit/sv/sshd /run/runit/service/sshd

## create user with sudo permissions
getuserandpass
useradd --create-home $name
echo -e "$pass1\n$pass1" | passwd $name
usermod -aG wheel $name
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL' >> /etc/sudoers

