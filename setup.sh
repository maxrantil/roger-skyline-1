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
		dialog --no-cancel --inputbox "What ssh port do you want to change to?(recommented range: 49152-65535)" 10 60 2>pchoice

		read SSH_PORT <<< $(cat pchoice)

		re='^(0|[1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$'
		if ! [[ ${SSH_PORT} =~ $re ]] ; then
			SSH_PORT=(61216);
		fi
		sed -i 's/#Port 22/Port '${SSH_PORT}'/g' /etc/ssh/sshd_config
		rm pchoice
		sv restart sshd
		dialog --no-cancel --title "Secure ssh" --msgbox "Be sure you have copied the ssh pub keys from your host into the client before pressing OK\n\n'ssh-copy-id -i ~/.ssh/<pubkey> $name@$ethernet -p ${SSH_PORT}'" 10 70
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

installpkg() {  \
		pacman -S --noconfirm "$1" >/dev/null 2>&1
		}

## Script Main starts here
####

pacman_candy

pacman -Sy --noconfirm openssh-runit >/dev/null 2>&1

ln -s /etc/runit/sv/sshd /run/runit/service/

## Create user with sudo rights
###
getuserandpasswd
useradd --create-home $name
echo -e "$pass1\n$pass1" | passwd $name
usermod -aG wheel $name
sed -i '/# %wheel ALL=(ALL:ALL) ALL/s/^# //g' /etc/sudoers

## Secure ssh
###
getip
securessh
sv restart sshd


## Enable Firewall & Protect against a DoS attack
###
installpkg ipset

installpkg iptables
installpkg iptables-runit
ln -s /etc/runit/sv/iptables/ /run/runit/service/

installpkg apache
installpkg apache-runit
ln -s /etc/runit/sv/apache/ /run/runit/service/

installpkg fail2ban
installpkg fail2ban-runit
ln -s /etc/runit/sv/fail2ban/ /run/runit/service/

cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

echo -e "# Fail2Ban configuration file

[Definition]
failregex = ^<HOST> -.*\"GET.*

# Notes.: regex to ignore. If this regex matches, the line is ignored.
ignoreregex =" > /etc/fail2ban/filter.d/http-get-dos.conf

echo -e "# Fail2Ban configuration file

[Definition]
failregex = ^<HOST> -.*\"POST.*

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


## portscanning attack protection
ipset create port_scanners hash:ip family inet hashsize 32768 maxelem 65536 timeout 600
ipset create scanned_ports hash:ip,port family inet hashsize 32768 maxelem 65536 timeout 60
iptables -A INPUT -m state --state INVALID -j DROP
iptables -A INPUT -m state --state NEW -m set ! --match-set scanned_ports src,dst -m hashlimit --hashlimit-above 1/hour --hashlimit-burst 5 --hashlimit-mode srcip --hashlimit-name portscan --hashlimit-htable-expire 10000 -j SET --add-set port_scanners src --exist
iptables -A INPUT -m state --state NEW -m set --match-set port_scanners src -j DROP
iptables -A INPUT -m state --state NEW -j SET --add-set scanned_ports src,dst
## firewall
iptables -A INPUT -p tcp -m tcp -m multiport ! --dports 80,443,$SSH_PORT -j DROP
##outgoing traffic allowed
iptables -I OUTPUT -o eth0 -j ACCEPT
iptables -I INPUT -i eth0 -m state --state ESTABLISHED,RELATED -j ACCEPT

## Save the rules
#iptables-save -f /etc/iptables/iptables.rules

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

curl https://raw.githubusercontent.com/maxrantil/roger-skyline-1/master/gen_certificates.sh > gen_certificates.sh
bash gen_certificates.sh

sed -i '/#LoadModule ssl_module modules\/mod_ssl.so/s/^#//g' /etc/httpd/conf/httpd.conf
sed -i '/#LoadModule socache_shmcb_module modules\/mod_socache_shmcb.so/s/^#//g' /etc/httpd/conf/httpd.conf
sed -i 's/ServerAdmin you@example.com/ServerAdmin "'${name}@${hostname}'"/g' /etc/httpd/conf/httpd.conf
sed -i 's/#ServerName www.example.com:80/ServerName "'${hostname}':80"/g' /etc/httpd/conf/httpd.conf
sed -i '/#Include conf\/extra\/httpd-ssl.conf/s/^#//g' /etc/httpd/conf/httpd.conf
sed -i '/#Include conf\/extra\/httpd-vhosts.conf/s/^#//g' /etc/httpd/conf/httpd.conf
sed -i 's/ServerName www.example.com:443/ServerName "'${hostname}':443"/g' /etc/httpd/conf/extra/httpd-ssl.conf
sed -i 's/ServerAdmin you@example.com/ServerAdmin "'${name}@${hostname}'"/g' /etc/httpd/conf/extra/httpd-ssl.conf
echo -e "<VirtualHost *:80>
	Redirect / https://${ethernet}
</VirtualHost>" > /etc/httpd/conf/extra/httpd-vhosts.conf

## Website

echo -e "<!DOCTYPE html>
<html>
<head>
	<title>Bitcoin</title>
	<link rel=\"stylesheet\" href=\"styles.css\">
</head>
<body>
	<div id=\"form-wrapper\">
		<br>
		<br>
		<br>
		<br>
		<br>
		<p>Login</p>
		<form action=\"index.html\" method=\"POST\">
			Username: <input type=\"text\" name=\"login\" value =\"\"/>
			<br/>
			Password: <input type=\"password\" name=\"passwd\" value =\"\"/>
			<input type=\"submit\" name=\"submit\" value=\"OK\"/>
		</form>
	</div>
</body>
</html>" > /srv/http/index.html

echo -e "body {
	background-image: url(https://c.ndtvimg.com/2021-05/umqnehr8_this-is-fine-meme-bitcoin-meme_625x300_19_May_21.jpg);
	background-repeat: repeat;
	height: 100vh;
}
p {
	color: #000000;
}
#form-wrapper {
	width:		22.5vh;
	height:		15vh;
	position:	absolute;
	top:		50%;
	left:		50%;
	margin-top:	-7.5vh;
	margin-left:	-11.25vh;
}
" > /srv/http/styles.css


## Crontab, Anacron & Cronie
###
installpkg cronie
installpkg cronie-runit

ln -s /etc/runit/sv/cronie/ /run/runit/service/

export VISUAL=vim
export EDITOR=vim

echo "export EDITOR='/usr/bin/vim'" >> ~/.bashrc
echo "export VISUAL='/usr/bin/vim'" >> ~/.bashrc
source ~/.bashrc

ln -s /bin/vim /usr/bin/vi


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
echo -e "# Update source to packages
@reboot		/etc/cron.weekly/update_packages	>/dev/null 2>&1
@midnight	~/scripts/monitor_cronfile.sh		>/dev/null 2>&1
@reboot		~/scripts/reload_iptables.sh		>/dev/null 2>&1" >> mycron

#install new cron file
crontab mycron
rm mycron

# run at 4 AM
sed -i 's/START_HOURS_RANGE=3-22/START_HOURS_RANGE=4-23/g' /etc/anacrontab

# create a /etc/crontab file for the evaluation
cat /var/spool/cron/root > /etc/crontab

# script for check if there is changes to cronfile
mkdir -p scripts
cat > monitor_cronfile.sh <<'EOF'
#!/bin/bash

file=/etc/crontab
old=/var/log/crontab_old
new=/var/log/crontab_new

if [ ! -f $old ] ; then
	cat $file | tee $old
	exit
fi

cat $file | tee $new

if [ "$(diff $old $new)" != "" ] ; then
	echo "it wasn't me?" | mail -s "crontab has been modified!" root@localhost
	cat $file | tee $old
fi
EOF
chmod 755 monitor_cronfile.sh
mv monitor_cronfile.sh scripts

cat > reload_iptables.sh <<'EOF'
#!/bin/sh

ipset create port_scanners hash:ip family inet hashsize 32768 maxelem 65536 timeout 600
ipset create scanned_ports hash:ip,port family inet hashsize 32768 maxelem 65536 timeout 60
iptables -A INPUT -m state --state INVALID -j DROP
iptables -A INPUT -m state --state NEW -m set ! --match-set scanned_ports src,dst -m hashlimit --hashlimit-above 1/hour --hashlimit-burst 5 --hashlimit-mode srcip --hashlimit-name portscan --hashlimit-htable-expire 10000 -j SET --add-set port_scanners src --exist
iptables -A INPUT -m state --state NEW -m set --match-set port_scanners src -j DROP
iptables -A INPUT -m state --state NEW -j SET --add-set scanned_ports src,dst
##outgoing traffic allowed
iptables -I OUTPUT -o eth0 -j ACCEPT
iptables -I INPUT -i eth0 -m state --state ESTABLISHED,RELATED -j ACCEPT
EOF
echo "iptables -A INPUT -p tcp -m tcp -m multiport ! --dports 80,443,${SSH_PORT} -j DROP" >> reload_iptables.sh
chmod 755 reload_iptables.sh
mv reload_iptables.sh scripts

installpkg postfix
installpkg postfix-runit

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
pacman -S --noconfirm mailx

echo -e "set mbox_type=Maildir
set folder=\"/root/mail\"
set mask=\"!^\\\\\\\\.[^.]\"
set mbox=\"/root/mail\"
set record=\"+.Sent\"
set postponed=\"+.Drafts\"
set spoolfile=\"/root/mail\"" > .muttrc

sv stop apache
sv start apache

rm setup.sh
rm gen_certificates.sh

dialog --title "Done" --msgbox "Before you poweroff write '# mutt' answer 'Y' 'q' then poweroff, before starting it go into 'Settings/Network' and add an 'Adapter 2' with 'Host-only' before starting again to set a static ip for the server."  10 60
