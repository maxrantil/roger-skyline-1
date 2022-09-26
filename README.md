# roger-skyline-1 on Artix runit
"This subject follows Init where you have learn some of basics commands and first
reflexes in system and network administration. This one will be a concrete example of
the use of those commands and will let you start your own first web server."

download the (artix-base-runit-20220123-x86_64.iso) <a href=http://ftp.ludd.ltu.se/artix/iso/>file</a> and open it in a VM (I use VirtualBox): 
```
Name: 'roger-skyline-1'
Type: 'Linux'
Version: 'Linux 2.6 / 3.x / 4.x (64-bit)'
```

Then start the VM and login as 'root' with passwork 'artix'
```
root
artix
```

## option 1: run from script

```
curl https://raw.githubusercontent.com/maxrantil/roger-skyline-1/master/deploy.sh > deploy.sh && bash deploy.sh
```

## option 2: manually

To list partitions
```
lsblk
```
or
```
fdisk -l
```

for me it's /dev/sda
```
fdisk /dev/sda
o
n
p
enter
enter
+1G
n
p
enter
enter
+2.2G
n
p
enter
enter
+4.2G
n
p
enter
enter
enter
w
```

I chose to do 4 partitions for this exercise.
/dev/sda1 = /mnt/boot
/dev/sda2 = swap
/dev/sda3 = /mnt
/dev/sda4 = /mnt/home

first partion = boot partion (good size is 1G)
second partition = swap partition (good size 115-120% of base memory)
third partiton = root partion, this is where all programs is gonna be. (4.2G)
fourth partiton = home partition, where you have all your documents and the rest of stuff (good size, all the rest)

make filesystems:
on three partitions
```
mkfs.ext4 /dev/sda1
mkfs.ext4 /dev/sda3
mkfs.ext4 /dev/sda4
```

make swap partion on /dev/sda2
```
mkswap /dev/sda2
swapon /dev/sda2
```

mount root partion:
```
mount /dev/sda3 /mnt
```

make home folder:
```
mkdir -p /mnt/home
```

make directory boot:
```
mkdir -p /mnt/boot
```

mount boot partion:
```
mount /dev/sda1 /mnt/boot
```

mount home partion:
```
mount /dev/sda4 /mnt/home
```


# install Artix:
with the necessary packages
```
basestrap /mnt base base-devel runit elogind-runit linux linux-firmware vim
```

change to UUID:
```
fstabgen -U /mnt >> /mnt/etc/fstab
```

change root to make it boot from the right place:
```
artix-chroot /mnt
```


## NetworkManager and grub:

install NetworkManager
```
pacman -Sy networkmanager networkmanager-runit network-manager-applet
```

install grub without UEFI
```
pacman -S grub && grub-install --target=i386-pc /dev/sda && grub-mkconfig -o /boot/grub/grub.cfg
```

set new password for root:
```
passwd
```

configure language:
```
vim /etc/locale.gen
```
uncomment the language you want. i choose en_US.UTF-8 
write in this file /etc/locale.conf :
```
echo LANG=en_US.UTF-8 > /etc/locale.conf
```
```
locale-gen
```

change timezone:
```
ln -sf /usr/share/zoneinfo/Europe/Helsinki /etc/localtime
```
make the system run from the hardware clock
```
hwclock --systohc
```

set hostname of choice in file /etc/hostname :
```
echo <hostname> > /etc/hostname
```

edit /etc/hosts:
```
127.0.0.1   localhost
::1         localhost
127.0.0.1  <hostname>.localdomain <hostname>
```

exit chroot environment:
```
exit
```

unmount:
```
umount -R /mnt
```

```
poweroff
```
Once shutdown is complete, remove your installation media. If all went well, you should boot into your new system.
Log in as your root to complete the post-installation configuration.



# On fresh install

log in with root and the new password you have chose

enable NetworkManager for internet access:
```
sudo ln -s  /etc/runit/sv/NetworkManager /run/runit/service/
```


## optin 1, run script

```
curl https://raw.githubusercontent.com/maxrantil/roger-skyline-1/master/setup.sh > setup.sh && sh setup.sh
```

## option 2, manually

add user:
```
useradd --create-home <username>
```
create password for user:
```
passwd <username>
```
add user to the wheel group:
```
usermod -aG wheel <username>
```
Now edit the file /etc/sudoers so that the wheel group has sudo permissions. To do this, open the sudoer's file and uncomment the line # %wheel ALL=(ALL) ALL
```
EDITOR=vim visudo
```
to test if its correcct:
```
su <username>
```
```
whoami
> <username>
```
```
sudo whoami
> root
```

## ssh (secure shell):

install:
```
sudo pacman -Sy openssh-runit openssh
```
enable ssh:
```
sudo ln -s  /etc/runit/sv/sshd /run/runit/service/sshd
```
copy public key from host to connect to client without password:
```
ssh-copy-id -i ~/.ssh/<pub key> <username>@<ip> -p <port>
```

change port in /etc/ssh/sshd_config file,
uncomment the line with '#Port 22' and change the integer to your choice.
(https://en.wikipedia.org/wiki/List_of_TCP_and_UDP_port_numbers) for detailed documentation.

i choose 'Port 61216'.
restart sshd service:
```
sudo sv restart sshd
```
exit and log in with your new port.
```
ssh -t <username>@<ip> -p <port>
```

for more secure ssh:
in /etc/ssh/sshd_config file change:
```
from
#PermitRootLogin prohibit-password
to
PermitRootLogin no
```
```
from
#PasswordAuthentication yes
to
PasswordAuthentication no
```



## firewall (iptables) & Protect against a DoS attack and portscanning

```
pacman -S --noconfirm iptables iptables-runit
ln -s /etc/runit/sv/iptables/ /run/runit/service/
```
```
pacman -S --noconfirm apache apache-runit
ln -s /etc/runit/sv/apache/ /run/runit/service/
```
```
pacman -S --noconfirm fail2ban fail2ban-runit
ln -s /etc/runit/sv/fail2ban/ /run/runit/service/
```

only change jail.local file in fail2ban so before that you need to create it
```
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
```
add these rules to the jail.local file
```
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
```

to protect against a DoS attack create two files
```
echo -e "# Fail2Ban configuration file

[Definition]
failregex = ^<HOST> -.*\"GET.*

# Notes.: regex to ignore. If this regex matches, the line is ignored.
ignoreregex =" > /etc/fail2ban/filter.d/http-get-dos.conf
```
```
echo -e "# Fail2Ban configuration file

[Definition]
failregex = ^<HOST> -.*\"POST.*

# Notes.: regex to ignore. If this regex matches, the line is ignored.
ignoreregex =" > /etc/fail2ban/filter.d/http-post-dos.conf
```
# portscanning attack protection
add these rules to iptables to only open the ports you use and protect against portscanning

```
ipset create port_scanners hash:ip family inet hashsize 32768 maxelem 65536 timeout 600
ipset create scanned_ports hash:ip,port family inet hashsize 32768 maxelem 65536 timeout 60
iptables -A INPUT -m state --state INVALID -j DROP
iptables -A INPUT -m state --state NEW -m set ! --match-set scanned_ports src,dst -m hashlimit --hashlimit-above 1/hour --hashlimit-burst 5 --hashlimit-mode srcip --hashlimit-name portscan --hashlimit-htable-expire 10000 -j SET --add-set port_scanners src --exist
iptables -A INPUT -m state --state NEW -m set --match-set port_scanners src -j DROP
iptables -A INPUT -m state --state NEW -j SET --add-set scanned_ports src,dst
```
# firewall
```
iptables -A INPUT -p tcp -m tcp -m multiport ! --dports 80,443,<ssh_port> -j DROP
```
#outgoing traffic allowed
```
iptables -I OUTPUT -o eth0 -j ACCEPT
iptables -I INPUT -i eth0 -m state --state ESTABLISHED,RELATED -j ACCEPT
```


## SSL Cert
I did a script for this part, study it if you like or just run it.
first add these like into /etc/httpd/conf/cert_ext.cnf
```
echo -e "[req]
default_bit = 4096
distinguished_name = req_distinguished_name
prompt = no

[req_distinguished_name]
countryName             = FI
stateOrProvinceName     = Nyland
localityName            = Helsinki
organizationName        = <name>" >> /etc/httpd/conf/cert_ext.cnf
```
then run the script
```
curl https://raw.githubusercontent.com/maxrantil/roger-skyline-1/master/gen_certificates.sh > gen_certificates.sh && sh gen_certificates.sh
```

then change these files: (be aware that you need to change whats inside <> to what your machine uses
```
sed -i '/#LoadModule ssl_module modules\/mod_ssl.so/s/^#//g' /etc/httpd/conf/httpd.conf
sed -i '/#LoadModule socache_shmcb_module modules\/mod_socache_shmcb.so/s/^#//g' /etc/httpd/conf/httpd.conf
sed -i 's/ServerAdmin you@example.com/ServerAdmin "<name>@<hostname>"/g' /etc/httpd/conf/httpd.conf
sed -i 's/#ServerName www.example.com:80/ServerName "<name>:80"/g' /etc/httpd/conf/httpd.conf
sed -i '/#Include conf\/extra\/httpd-ssl.conf/s/^#//g' /etc/httpd/conf/httpd.conf
sed -i '/#Include conf\/extra\/httpd-vhosts.conf/s/^#//g' /etc/httpd/conf/httpd.conf
sed -i 's/ServerName www.example.com:443/ServerName "<hostname>:443"/g' /etc/httpd/conf/extra/httpd-ssl.conf
sed -i 's/ServerAdmin you@example.com/ServerAdmin "<name>@<hostname>"/g' /etc/httpd/conf/extra/httpd-ssl.conf
echo -e "<VirtualHost *:80>
	Redirect / https://<ip_address>
</VirtualHost>" > /etc/httpd/conf/extra/httpd-vhosts.conf
```


## Website

Here is a simple webpage that i used:
```
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
```
```
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
```



## Crontab, Anacron & Cronie
https://www.adminschoice.com/crontab-quick-reference
```
pacman -S --noconfirm cronie cronie-runit
ln -s /etc/runit/sv/cronie/ /run/runit/service/
```

some settings for easier use:
```
export VISUAL=vim
export EDITOR=vim

echo "export EDITOR='/usr/bin/vim'" >> ~/.bashrc
echo "export VISUAL='/usr/bin/vim'" >> ~/.bashrc
source ~/.bashrc

ln -s /bin/vim /usr/bin/vi
```

# Create a script that updates all sources of packages once per week at 4AM and on reboot

I choose to put this cron-action in anacron because anacron will know to run the script even if the server was not powered on at the exakt time the script was meant to run.
```
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
```

to run it at 4AM i changed the file:
```
sed -i 's/START_HOURS_RANGE=3-22/START_HOURS_RANGE=4-23/g' /etc/anacrontab
```

I did two more scripts that i put in a folder
```
mkdir -p scripts
```
```
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
```
```
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
echo "iptables -A INPUT -p tcp -m tcp -m multiport ! --dports 80,443,<ssh_port> -j DROP" >> reload_iptables.sh
chmod 755 reload_iptables.sh
mv reload_iptables.sh scripts
```

Then I created the crontabs rules:
```
echo -e "@reboot		/etc/cron.weekly/update_packages	>/dev/null 2>&1
@midnight	~/scripts/monitor_cronfile.sh		>/dev/null 2>&1
@reboot		~/scripts/reload_iptables.sh		>/dev/null 2>&1" >> mycron
crontab mycron
rm mycron
```

To be able to send local mail we need:
```
pacman -S --noconfirm postfix postfix-runit
ln -s /etc/runit/sv/postfix/ /run/runit/service/
```
```
pacman -S --noconfirm mutt
pacman -S --noconfirm mailx
```

and make some configuration
```
echo -e "
myhostname = localhost
mydomain = localdomain
mydestination = \$myhostname, localhost.\$mydomain, localhost
inet_interfaces = \$myhostname, localhost
mynetworks_style = host
default_transport = error: outside mail is not deliverable" >> /etc/postfix/main.cf
```

It's supposedly not good to read mail from root so lets redirect them to the user we created:
```
sed -i 's/#root:		you/root:		<name>/g' /etc/postfix/aliases
```
```
newaliases
```
```
postconf -e "home_mailbox = mail/"
```
```
sv restart postfix
```
```
echo -e "set mbox_type=Maildir
set folder=\"/root/mail\"
set mask=\"!^\\\\\\\\.[^.]\"
set mbox=\"/root/mail\"
set record=\"+.Sent\"
set postponed=\"+.Drafts\"
set spoolfile=\"/root/mail\"" > .muttrc
```

lastly restart the apache server
```
sv restart apache
```

# Static ip
https://www.calculator.net/ip-subnet-calculator.html

In Virtual Box user interface you should do some configuration for a static IP. At the top corner there is a 'Tools' or  'Global Tools' options , press that and then 'Network'. Next press 'Create', and change to 'Configure Adapter Manually'. The thing we want to change here is the 'IPv4 Network Mask' to '255.255.255.252'. Be sure to have the DHCP Server unchecked. You don't want it enabled.
This will create the prerequisite for opening a "Host-only Network". Now be sure that your VM is off and select 'Settings' > 'Network' and then enable 'Adapter 2'. Now choose  'Attached to: Host-only Adapter' then the 'Name' of the "Host-only Network" that you opened before. For me it is 'vboxnet0'.
