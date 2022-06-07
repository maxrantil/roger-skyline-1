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
		if	dialog --stdout --title "Secure ssh" --yesno "SSH public key authentication?" 10 60; then
			sed -i '/#PubkeyAuthentication yes/s/^#//g' /etc/ssh/sshd_config
		fi
		if	dialog --title "Secure ssh" --yesno "Turn off password authentication?" 10 60; then
			sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
		fi
		if	dialog --title "Secure ssh" --yesno "Turn off root login?" 10 60; then
			sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/g' /etc/ssh/sshd_config
		fi
		}

getip() { \
		device=$(nmcli con show | awk '/DEVICE/ {getline ; print $NF}')
		con_name=$(nmcli con show | awk '/DEVICE/ {getline ; print $1" "$2" "$3}')
		gateway=$(ip r | awk '/default/ {print $3}')
		ethernet=$(ip r | awk '/'$gateway'/ {print $9}')
		broadcast=$(ip a | awk '/'$ethernet'/ {print $4}')
		eth_mask=$(ip a | awk '/'$ethernet'/ {print $2}')
		}

## Script Main starts here
####

## Install packages and enable them
###

pacman -S --noconfirm openssh-runit ufw ufw-runit

ln -s /etc/runit/sv/sshd /run/runit/service/
ln -s /etc/runit/sv/ufw /run/runit/service/
sv restart sshd
sv restart ufw

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
#echo $device device
#echo $gateway gateway
#echo $ethernet ethernet
#echo $broadcast broadcast
#echo $eth_mask ethernet/netmask
nmcli con mod "$con_name" ipv4.addr "${ethernet}/30" ipv4.gateway $gateway ipv4.dns "8.8.8.8, 8.8.4.4" ipv4.method "manual"
nmcli con reload
sv restart NetworkManager

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

cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# To test if it works you can use Slowloris
#pacman -S --nnoconfirm python-pip
#pip3 install slowloris
#slowloris example.com

## List all services
###
# pstree

## Cronie
###
pacman -S --noconfirm cronie


#reboot



