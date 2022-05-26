# roger-skyline-1 on Artix Linux

download the (artix-base-runit-20220123-x86_64.iso) file from http://ftp.ludd.ltu.se/artix/iso/
and open that in a new VM (I use VirtualBox) and choose the Name of choice, Type: 'Linux', Version: 'Linux 2.6 / 3.x / 4.x (64-bit)'.

## to check partitions.
first command: 
```
lsblk
```

next command for dividing partitions:
```
sudo fdisk -l
```

check what partition to split. for me it is /dev/sda
```
sudo fdisk /dev/sda
```

I choosed to do 3 partitions for this exercise.
/dev/sda1 = /mnt/boot
/dev/sda2 = /mnt
/dev/sda3 = /mnt/home

first partion = boot partion (good size is 1G)
second partion = root partion, this is where all programs is gonna be. (4.2G)
third partion = home partition, where you have all your documents and the rest of stuff (good size, all the rest)

commands:
p = print
n = new
at the end:
w = write (this will wipe everything)
d = delete (if you do something wrong)

Make filesystems:
on all three partitions
```
sudo mkfs.ext4 <partion>     e.g. /dev/sda1 & /dev/sda2 & /dev/sda3
```

mount root partion:
```
sudo mount /dev/sda2 /mnt
```

make home folder:
```
sudo mkdir /mnt/home
```

make directory boot:
```
sudo mkdir /mnt/boot
```

mount boot partion:
```
sudo mount /dev/sda1 /mnt/boot
```

mount home partion:
```
sudo mount /dev/sda3 /mnt/home
```

# install Artix:
```
basestrap /mnt base base-devel runit elogind-runit linux linux-firmware vim
```

change to UUID:
write it out:
```
su root
```

```
fstabgen -U /mnt >> /mnt/etc/fstab
```

change root to make it boot from the right place:
```
artix-chroot /mnt
```

# install what you need:
```
pacman -S networkmanager networkmanager-runit network-manager-applet
```

install without UEFI
```
pacman -S grub
```

```
grub-install --target=i386-pc /dev/sda
```

```
grub-mkconfig -o /boot/grub/grub.cfg
```

set password:
```
passwd
```

configure language:
```
vim /etc/locale.gen
```
uncomment the language you want. i choose en_US.UTF-8 
```
locale-gen
```

```
vim /etc/locale.conf
```
write in this file:
```
LANG=en_US.UTF-8
```

change timezone:
```
ln -sf /usr/share/zoneinfo/Europe/Helsinki /etc/localtime
```
make the system run from the hardware clock
```
hwclock --systohc
```

set hostname:
```
vim /etc/hostname
```

edit /etc/hosts:
```
127.0.0.1   localhost
::1         localhost
127.0.0..1  <hostname of choice>.localdomain <hostname of choice>
```

add user:
```
# pacman --sync sudo
```

```
# useradd --create-home john
```

```
# passwd john
```

```
# usermod -aG wheel john
```

```
EDITOR=vim visudo
```
Now edit the file sudoers so that the wheel group is activated. To do this, open the sudoer's file and uncomment the line  %wheel ALL=(ALL) ALL

to test if its correcct:
```
# su - john
```

```
# whoami
> john
```

```
# sudo whoami
> root
```

```
exit
```

```
umount -R /mnt
```

```
reboot
```

enable services:
```
ln -s  /etc/runit/sv/NetworkManager /run/runit/service/NetworkManager
```
