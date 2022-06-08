#!/bin/bash

## FUNCTIONS
####

getuserandpasswd() { \
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
		sv restart sshd
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

pacman -Syu --noconfirm openssh-runit ufw ufw-runit

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
ufw allow ${port}

#for our web server we also need to open for port 80(http) and port 442(TCP/IP):
ufw allow 80/tcp
ufw allow 443/tcp

## Bonus, hide the server so noone cant ping it
###
sed -i '/^# ok icmp codes for INPUT/a -A ufw-before-input -p icmp --icmp-type echo-request -j DROP' /etc/ufw/before.rules

#enable the firewall:
ufw --force enable



##Protect against a DDos attack
###
pacman -S --noconfirm iptables iptables-runit ipset fail2ban fail2ban-runit apache apache-runit
ln -s /etc/runit/sv/iptables/ /run/runit/service/
ln -s /etc/runit/sv/fail2ban/ /run/runit/service/
ln -s /etc/runit/sv/apache/ /run/runit/service/

cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

echo -e "[sshd]
mode = aggressive
enabled = true
logpath = /var/log/httpd/access_log
backend = auto
maxretry = 3
bantime = 600" > /etc/fail2ban/jail.d/sshd.local

echo -e "# Fail2Ban configuration file
# You should set up in the jail.conf file, the maxretry and findtime carefully in order to avoid false positives.

[Definition]
# Option: failregex
# NOTE: The failregex assumes a particular vhost LogFormat:
#           LogFormat "%t [%v:%p] [client %h] \"%r\" %>s %b \"%{User-Agent}i\""
#       This is more in-keeping with the error log parser that contains an explicit [client xxx.xxx.xxx.xxx]
#       but you could obviously alter this to match your own (or the default LogFormat)
failregex = \[[^]]+\] \[.*\] \[client <HOST>\] \"GET .*

# Notes.: regex to ignore. If this regex matches, the line is ignored.
ignoreregex =" > /etc/fail2ban/filter.d/http-get-dos.conf

echo -e "# Fail2Ban configuration file
# You should set up in the jail.conf file, the maxretry and findtime carefully in order to avoid false positives.

[Definition]
# Option: failregex
# NOTE: The failregex assumes a particular vhost LogFormat:
#           LogFormat "%t [%v:%p] [client %h] \"%r\" %>s %b \"%{User-Agent}i\""
#       This is more in-keeping with the error log parser that contains an explicit [client xxx.xxx.xxx.xxx]
#       but you could obviously alter this to match your own (or the default LogFormat)
failregex = \[[^]]+\] \[.*\] \[client <HOST>\] \"POST .*

# Notes.: regex to ignore. If this regex matches, the line is ignored.
ignoreregex =" > /etc/fail2ban/filter.d/http-post-dos.conf

echo -e "
# Simple attempt to block very basic DOS attacks over GET
# Tolerate ~3.3 GET/s in 30s (100 GET in less then 30s)
[http-get-dos]
enabled = true
port = http,https
filter = http-get-dos
logpath = /var/log/httpd/access_log
maxretry = 100
findtime = 30
bantime = 6000

# Simple attempt to block very basic DOS attacks over POST
# Tolerate ~2 POST/s in 30s (60 POST in less then 30s)
[http-post-dos]
enabled = true
port = http,https
filter = http-post-dos
logpath = /var/log/httpd/access_log
maxretry = 60
findtime = 30
bantime = 6000" >> /etc/fail2ban/jail.local

ufw reload
sv restart fail2ban

# Command to check why if wont work
# /usr/bin/fail2ban-client -vv start

# Unban 
# fail2ban-client set jail-name unbanip <ip>
# fail2ban-client unban --all

# To test if it works you can use Slowloris
#pacman -S --nnoconfirm python-pip
#pip3 install slowloris
#slowloris example.com

## Port scan
###
#pacman -S --noconfirm nmap
## install nslookup and dig
#pacman -S --noconfirm bind

## First flush
# iptables -F
## List your settings
# iptables -L
## Block ip
# iptables -I INPUT -s <ip> -j DROP
## BLock ip with submask
# iptables -I INPUT -s <ip/netmask> -j DROP
## Unban ip (first list)
# iptables -L --line-numbers
## Then specify the ip in the list
# iptables -D INPUT <list number>
## Block all traffic to the web server
# iptables -I INPUT -p tcp --dport 80 -j DROP
## Accept only one ip
# iptables -I INPUT -p tcp --dport 80 <ip> -j ACCEPT

ipset create port_scanners hash:ip family inet hashsize 32768 maxelem 65536 timeout 600
ipset create scanned_ports hash:ip,port family inet hashsize 32768 maxelem 65536 timeout 60
iptables -A INPUT -m state --state INVALID -j DROP
iptables -A INPUT -m state --state NEW -m set ! --match-set scanned_ports src,dst -m hashlimit --hashlimit-above 1/hour --hashlimit-burst 5 --hashlimit-mode srcip --hashlimit-name portscan --hashlimit-htable-expire 10000 -j SET --add-set port_scanners src --exist
iptables -A INPUT -m state --state NEW -m set --match-set port_scanners src -j DROP
iptables -A INPUT -m state --state NEW -j SET --add-set scanned_ports src,dst

## Save the rules
# sudo /sbin/iptables-save


## scan the ports
## Commands for scanning
## Triple-handshake scan (full tcp connection)
# nmap -sT -p 80,443 <ip/submask>
## Stealthy Syn Scan (half-open)
# nmap -sS -p 80,443 <ip/submask>
## Aggressive mode
# nmap -A <ip>
## Stealthy Syn Scan with decoil (half-open)
# nmap -sS -D <decoil ip> <ip>
## Use scripts (https://nmap.org/nsedoc/categories/)
# nmap --script vuln <ip>



## List all services
###
# pstree

## Cronie
###
pacman -S --noconfirm cronie cronie-runit
ln -s /etc/run/sv/cronie/ /run/runit/service/


dialog --title "Done" --msgbox "After this the VM will poweroff."  10 60

poweroff

