# roger-skyline-1 on Artix runit

download the (artix-base-runit-20220123-x86_64.iso) file from http://ftp.ludd.ltu.se/artix/iso/
and open that in a VM (I use VirtualBox): 
```
Name: 'roger-skyline-1'
Type: 'Linux'
Version: 'Linux 2.6 / 3.x / 4.x (64-bit)'
```
After you have created your VM you should do some settings in the Virtual Box UI for later being able to setting up a static ip. At the top left of the window there is a 'Tools' options, press that and then 'Network'. Next press 'Create', and change to 'Configure Adapter Manually'. The thing we want to change here is the 'IPv4 Network Mask' to '255.255.255.252'. Be sure to have the DHCP Server unchecked. You don't want it enabled.
This will create a prerequsite for opening a "Host-only Network". Now be sure that your VM is turned off and select it and go into 'Settings'. Choose 'Network' and then enable 'Adapter 2'. Choose 'Attached to: Host-only Adapter' and be sure to have the 'Name' of the "Host-only Network" you opened before. For me it is 'vboxnet0'.

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

to list partitions
```
lsblk
```
or
```
fdisk -l
```

for me it is /dev/sda
write paritions:
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
127.0.0..1  <hostname>.localdomain <hostname>
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
sudo ln -s  /etc/runit/sv/NetworkManager /run/runit/service/NetworkManager
```


## optin 1, run script

```
curl https://raw.githubusercontent.com/maxrantil/roger-skyline-1/master/setup.sh > setup.sh && bash setup.sh

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



## ufw (uncomplicated firewall)

install:
```
sudo pacman -S ufw ufw-runit
```
link it:
```
sudo ln -s /etc/runit/sv/ufw/ /run/runit/service/
```

open firewall for port 61216:
```
sudo ufw allow 61216/tcp
```
for our web server we also need to open for port 80(http) and port 442(TCP/IP):
```
sudo ufw allow 80/tcp
sudo ufw allow 442/tcp
```

enable the firewall:
```
sudo ufw enable
```

## cron
https://www.adminschoice.com/crontab-quick-reference

