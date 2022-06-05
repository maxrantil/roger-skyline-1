#!/bin/bash

## FUNCTIONS
####

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

refreshkeys() { \
#	dialog --infobox "Enabling Arch Repositories..." 4 40
	pacman -Sy --noconfirm artix-keyring artix-archlinux-support
	pacman -Su --noconfirm
	pacman-key --populate archlinux
}

## Script Main starts here
####

# Add key-ring
refreshkeys
echo "Server = https://ftp.ludd.ltu.se/mirrors/artix/$repo/os/$arch" > mirrors
echo "Server = https://mirrors.dotsrc.org/artix-linux/repos/$repo/os/$arch" >> mirrors
echo "Server = https://mirror.one.com/artix/$repo/os/$arch" >> mirrors
echo "Server = https://mirror.clarkson.edu/artix-linux/repos/$repo/os/$arch" >> mirrors
echo "Server = http://ftp.ntua.gr/pub/linux/artix-linux/$repo/os/$arch" >> mirrors
# Add them to pacman mirrors
tmp="$(mktemp)" && cat mirrors /etc/pacman.d/mirrorlist >"$tmp" && mv "$tmp" /etc/pacman.d/mirrorlist
rm mirrors


## Create user with sudo rights
###
getuserandpasswd
useradd --create-home $name
echo -e "$pass1\n$pass1" | passwd $name
usermod -aG wheel $name
sed -i '/# %wheel ALL=(ALL:ALL) ALL/s/^# //g' /etc/sudoers

## Install packages and enable them
###
pacman -S --noconfirm openssh-runit openssh ufw ufw-runit

ln -s /etc/runit/sv/sshd /run/runit/service/sshd
ln -s /etc/runit/sv/ufw /run/runit/service/ufw

## Static IP
###
device=$(nmcli con show | awk '/DEVICE/ {getline ; print $NF}')
gateway=$(ip r | awk '/default/ {print $3}')
ethernet=$(ip r | awk '/'$gateway'/ {print $9}')
broadcast=$(ip a | awk '/'$ethernet'/ {print $4}')
eth_mask=$(ip a | awk '/'$ethernet'/ {print $2}'
)
echo $gateway gateway
echo $ethernet ethernet
echo $broadcast broadcast
echo $eth_mask ethernet/netmask

dialog --"Set static ip"
#nmcli con mod "Wired connection 1"
#  ipv4.addresses "HOST_IP_ADDRESS/IP_NETMASK_BIT_COUNT"
#  ipv4.gateway "IP_GATEWAY"
#  ipv4.dns "PRIMARY_IP_DNS,SECONDARY_IP_DNS"
#  ipv4.dns-search "DOMAIN_NAME"
#  ipv4.method "manual"

#nmcli con mod "Wired connection 1" ipv4.address "172.20.10.4/30" ipv4.gateway "172.20.10.1" ipv4.dns "8.8.8.8, 8.8.4.4" ipv4.dns-search "google" ipv4.method "manual"
#dialog --title "Setup Done" --msgbox "After this the computer will reboot."  10 60
#nmcli con mod "Wired connection 1" ipv4.address "172.20.10.14/30" ipv4.gateway "172.20.10.1" ipv4.method "manual"

## List all services
###
# Install Rust
#cat <<EOF | curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh
#1
#EOF
#source $HOME/.cargo/env
## Install rsv (to list all running processes)
#git clone https://github.com/JojiiOfficial/rsv
#cd rsv
#cargo build --release
##sudo rsv list --enabled --down # list all enabled services which aren't running
##sudo rsv list --disabled/--enabled # list all disabled/enabled services 
##sudo rsv enable cupsd # enabled cupsd
##sudo rsv start cupsd # start cupsd service (enable if service is disabled)

#reboot
