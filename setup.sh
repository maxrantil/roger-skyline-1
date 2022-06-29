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

pacman_candy() { \
		grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
		sed -Ei "s/^#(ParallelDownloads).*/\1 = 5/;/^#Color$/s/#//" /etc/pacman.conf
		}
## Script Main starts here
####

pacman_candy

## Install packages and enable them
###

pacman -Sy --noconfirm openssh-runit
##pacman -Sy --noconfirm ufw ufw-runit

ln -s /etc/runit/sv/sshd /run/runit/service/
##ln -s /etc/runit/sv/ufw /run/runit/service/

## Create user with sudo rights
###
getuserandpasswd
useradd --create-home $name
echo -e "$pass1\n$pass1" | passwd $name
usermod -aG wheel $name
sed -i '/# %wheel ALL=(ALL:ALL) ALL/s/^# //g' /etc/sudoers

#echo "$pass1" | su $name
## Static IP
###
getip
## Dosnt work on wifi 
## Uncomment for ethernet static ip
#nmcli con mod "$con_name" ipv4.addr "${ethernet}/30" ipv4.gateway $gateway ipv4.dns "8.8.8.8, 8.8.4.4" ipv4.method "manual"
#nmcli con reload
#sv restart NetworkManager

## Secure ssh
###
securessh
sv restart sshd

## Enable Firewall (ufw)
###
#open firewall for ssh port:
##ufw allow ${port}/tcp

#for our web server we also need to open for port 80(http) and port 442(TCP/IP):
##ufw allow 80/tcp
##ufw allow 443/tcp

## Bonus, hide the server so noone cant ping it
###
##sed -i '/^# ok icmp codes for INPUT/a -A ufw-before-input -p icmp --icmp-type echo-request -j DROP' /etc/ufw/before.rules

#enable the firewall
##ufw --force enable



##Protect against a DoS attack
###
pacman -S --noconfirm ipset

pacman -S --noconfirm iptables iptables-runit
ln -s /etc/runit/sv/iptables/ /run/runit/service/

pacman -S --noconfirm apache apache-runit
ln -s /etc/runit/sv/apache/ /run/runit/service/

pacman -S --noconfirm fail2ban fail2ban-runit
ln -s /etc/runit/sv/fail2ban/ /run/runit/service/

cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

echo -e "# Fail2Ban configuration file

[Definition]
failregex = failregex = ^<HOST> -.*\"GET.*

# Notes.: regex to ignore. If this regex matches, the line is ignored.
ignoreregex =" > /etc/fail2ban/filter.d/http-get-dos.conf

echo -e "# Fail2Ban configuration file

[Definition]
failregex = failregex = ^<HOST> -.*\"POST.*

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

sv restart fail2ban
##ufw reload

# Command to check why if wont work
# /usr/bin/fail2ban-client -vv start

# Unban 
# fail2ban-client set jail-name unbanip <ip>
# fail2ban-client unban --all

## To test if it works you can use Slowloris
# pacman -S --noconfirm python-pip
# pip3 install slowloris
# slowloris example.com

## Port scan
###
#pacman -S --noconfirm nmap
## install nslookup and dig
#pacman -S --noconfirm bind

## First flush
#iptables -F
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
iptables -I INPUT -p tcp --dport 80 -j ACCEPT
iptables -I INPUT -p tcp --dport 443 -j ACCEPT
iptables -I INPUT -p tcp --dport ${port} -j ACCEPT
#iptables -A INPUT -p tcp -m tcp -m multiport ! --dports 80,443,${port} -j DROP

## Save the rules
/sbin/iptables-save

## scan the ports
## Commands for scanning
## tls Triple-handshake scan (full tcp connection)
# nmap -sT -p 80,443 <ip/submask>
## Stealthy Syn Scan (half-open)
# nmap -sS -p 80,443 <ip/submask>
## Aggressive mode
# nmap -A <ip>
## Stealthy Syn Scan with decoil (half-open)
# nmap -sS -D <decoil ip> <ip>
## Use scripts (https://nmap.org/nsedoc/categories/)
# nmap --script vuln <ip>


## SSL Cert
###

echo -e "[req]
default_bit = 4096
distinguished_name = req_distinguished_name
prompt = no

[req_distinguished_name]
countryName             = FI
stateOrProvinceName     = Nyland
localityName            = Helsinki
organizationName        = ${name}" >> /etc/httpd/conf/cert_ext.cnf

##openssl genrsa -out server.key 1024
##openssl rsa -in server.key.org -out server.key
##openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt

curl https://raw.githubusercontent.com/maxrantil/roger-skyline-1/master/gen_certificates.sh > gen_certificates.sh
chmod 755 gen_certificates.sh
bash gen_certificates.sh

sed -i '/#LoadModule ssl_module modules\/mod_ssl.so/s/^#//g' /etc/httpd/conf/httpd.conf
sed -i '/#LoadModule socache_shmcb_module modules\/mod_socache_shmcb.so/s/^#//g' /etc/httpd/conf/httpd.conf
sed -i 's/ServerAdmin you@example.com/ServerAdmin "'${name}@${hostname}'"/g' /etc/httpd/conf/httpd.conf
sed -i 's/#ServerName www.example.com:80/ServerName "'${hostname}':80"/g' /etc/httpd/conf/httpd.conf
sed -i '/#Include conf\/extra\/httpd-ssl.conf/s/^#//g' /etc/httpd/conf/httpd.conf
sed -i '/#Include conf\/extra\/httpd-vhosts.conf/s/^#//g' /etc/httpd/conf/httpd.conf
sed -i 's/ServerName www.example.com:443/ServerName "'${hostname}':443"/g' /etc/httpd/conf/extra/httpd-ssl
sed -i 's/ServerAdmin you@example.com/ServerAdmin "'${name}@${hostname}'"/g' /etc/httpd/conf/extra/httpd-ssl.conf
echo -e "<VirtualHost *:80>
	Redirect / https://${ethernet}
</VirtualHost>" > /etc/httpd/conf/extra/httpd-vhosts.conf

## Website

echo -e "<html>
<head>
<style type=\"text/css\">
 body {
  background-image: url(https://c.ndtvimg.com/2021-05/umqnehr8_this-is-fine-meme-bitcoin-meme_625x300_19_May_21.jpg);
  background-repeat: repeat;
 }
</style>
<title>Bitcoin</title>
</head>
<body>
	<br>
	<br>
	<p>Create or login</p>
	<br>
	<form action="create.php" method="POST">
		Username: <input type="text" name="login" value =""/>
		<br/>
		Password: <input type="password" name="passwd" value =""/>
		<input type="submit" name="submit" value="OK"/>
	</form>
</body>
</html>" > /srv/http/index.html

## List all services
###
# pstree


## Crontab, Cronie and Rsync 
###
pacman -S --noconfirm cronie cronie-runit
ln -s /etc/runit/sv/cronie/ /run/runit/service/

pacman -S --noconfirm rsync rsync-runit
ln -s /etc/runit/sv/rsyncd/ /run/runit/service/

export VISUAL=vim
export EDITOR=vim

echo "export EDITOR='/usr/bin/vim'" >> ~/.bashrc
echo "export VISUAL='/usr/bin/vim'" >> ~/.bashrc
source ~/.bashrc

##change user to $name and try it out there if it works on reboot
## Create a script that updates all sources of packages once per week at 4AM and on reboot
###
cat > update_packages <<'EOF'
#!/bin/sh

## Update all packages and sources
updates_log=/var/log/update_script.log

printf "\nPackages Update %s\n" "$(date)" >> $updates_log
pacman -Syu --noconfirm | sudo tee -a "$updates_log"

## Clear cache
pacman -Sc --noconfirm 2>&1
EOF
chmod 755 update_packages
mv update_packages /etc/cron.weekly

#write out current crontab
#echo new cron into cron file
echo "# Update source to packages
@reboot		/etc/cron.weekly/update_packages >/dev/null 2>&1
* * * * *	~/scripts/monitor_cronfile.sh >/dev/null 2>&1" >> mycron
#install new cron file
crontab mycron
rm mycron

# run at 4 AM
sed -i 's/START_HOURS_RANGE=3-22/START_HOURS_RANGE=4-23/g' /etc/anacrontab

#create a /etc/crontab file for the evaluation
cat /var/spool/cron/root > /etc/crontab

#script for check if there is changes to cronfile
mkdir -p scripts
touch ~/scrips/cron_md5
chmod 755 ~/scrips/cron_md5
cat > monitor_cronfile.sh <<'EOF'
#!/bin/sh

file=/etc/crontab
old_sum=/var/log/crontab_sum.old
new_sum=/var/log/crontab_sum.new

if [ ! -f $old_sum ]
then
	shasum < $file > $old_sum	# Compute old sum (if it doesn't exist)
	exit
fi

shasum < $file > $new_sum		# Compute new sum

if [ "$(diff $old_sum $new_sum)" != "" ]
then
	mail -s "crontab has been modified!" root
	shasum < $file > $old_sum
fi
EOF
chmod 755 monitor_cronfile.sh
mv monitor_cronfile.sh scrips

pacman -S --noconfirm postfix postfix-runit
ln -s /etc/runit/sv/postfix/ /run/runit/service/

echo -e "
myhostname = localhost
mydomain = localdomain
mydestination = \$myhostname, localhost.\$mydomain, localhost
inet_interfaces = \$myhostname, localhost
mynetworks_style = host
default_transport = error: outside mail is not deliverable" >> /etc/postfix/main.cf

sed -i 's/#root:		you/root:		'${name}'/g' /etc/postfix/aliases
newaliases
postconf -e "home_mailbox = mail/"
sv restart postfix


pacman -S --noconfirm mutt

echo -e "set mbox_type=Maildir
set folder=\"/root/mail\"
set mask=\"!^\\\\.[^.]\"
set mbox=\"/root/mail\"
set record=\"+.Sent\"
set postponed=\"+.Drafts\"
set spoolfile=\"/root/mail\"" > .muttrc


#enable the firewall :
##ufw reload
sv stop apache
sv start apache

rm setup.sh
rm gen_certificates.sh
echo "Done."
#dialog --title "Done" --msgbox "After this the VM will poweroff."  10 60