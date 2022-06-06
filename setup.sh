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

securessh() { \
		port=$(dialog --no-cancel --inputbox "What ssh port do you want to change to?(recommented range: 49152–65535)" 10 60 3>&1 1>&2 2>&3 3>&1)
		sed -i 's/#Port 22/Port '$port'/g' /etc/ssh/sshd_config
		dialog --no-cancel --title "Secure ssh" --msgbox "Be sure you have copied the ssh pub keys from your host into the client before pressing OK\n\n'ssh-copy-id -i ~/.ssh/<pubkey> $name@$ethernet -p $port'" 10 70
		flag=$(dialog --title "Secure ssh" --yesno "Public key authentication?" 0 0)
		if [ $flag -lt 1 ]; then
			sed -i '/#PubkeyAuthentication yes/s/^#//g' /etc/ssh/sshd_config
		fi
		flag=$(dialog --title "Secure ssh" --yesno "Turn off password authentication?" 0 0)
		if [ $flag -lt 1 ]; then
			sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication no/g' /etc/ssh/sshd_config
		fi
		flag=$(dialog --title "Secure ssh" --yesno "Turn off root login?" 0 0)
		if [ $flag -lt 1 ]; then
			sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/g' /etc/ssh/sshd_config
		fi
			;}

getip() { \
		device=$(nmcli con show | awk '/DEVICE/ {getline ; print $NF}')
		gateway=$(ip r | awk '/default/ {print $3}')
		ethernet=$(ip r | awk '/'$gateway'/ {print $9}')
		broadcast=$(ip a | awk '/'$ethernet'/ {print $4}')
		eth_mask=$(ip a | awk '/'$ethernet'/ {print $2}')
		;}

## Script Main starts here
####

## Install packages and enable them
###

pacman -S --noconfirm openssh-runit ufw ufw-runit sudo

ln -s /etc/runit/sv/sshd /run/runit/service/
ln -s /etc/runit/sv/ufw /run/runit/service/

## Create user with sudo rights
###
getuserandpasswd
useradd --create-home $name
echo -e "$pass1\n$pass1" | passwd $name
usermod -aG wheel $name
sed -i '/# %wheel ALL=(ALL:ALL) ALL/s/^# //g' /etc/sudoers

## Static IP
###

getip

echo $device device
echo $gateway gateway
echo $ethernet ethernet
echo $broadcast broadcast
echo $eth_mask ethernet/netmask
#dialog --"Set static ip"
#nmcli con mod "Wired connection 1"
#  ipv4.addresses "HOST_IP_ADDRESS/IP_NETMASK_BIT_COUNT"
#  ipv4.gateway "IP_GATEWAY"
#  ipv4.dns "PRIMARY_IP_DNS,SECONDARY_IP_DNS"
#  ipv4.dns-search "DOMAIN_NAME"
#  ipv4.method "manual"

#nmcli con mod "Wired connection 1" ipv4.address "172.20.10.4/30" ipv4.gateway "172.20.10.1" ipv4.dns "8.8.8.8, 8.8.4.4" ipv4.method "manual"
#dialog --title "Setup Done" --msgbox "After this the computer will reboot."  10 60
#nmcli con mod "Wired connection 1" ipv4.address "172.20.10.14/30" ipv4.gateway "172.20.10.1" ipv4.method "manual"
#restart NetworkManager

## Secure ssh
###
securessh
sv restart sshd

## Enable Firewall (ufw)
###
#open firewall for ssh port:
ufw allow ${port}/tcp

#for our web server we also need to open for port 80(http) and port 442(TCP/IP):
ufw allow 80/tcp
ufw allow 442/tcp

#enable the firewall:
ufw --force enable



##Protect against a DDos attack
###
pacman -S --noconfirm iptables iptables-runit fail2ban fail2ban-runit apache apache-runit
ln -s /etc/runit/sv/iptables/ /run/runit/service/
ln -s /etc/runit/sv/fail2ban/ /run/runit/service/
ln -s /etc/runit/sv/apache/ /run/runit/service/

## List all services
###
# pstree

## Cronie
###
pacman -S cronie


#reboot
