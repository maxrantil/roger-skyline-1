# continue from deploy.sh

passwd

TZuser=$(cat tzfinal.tmp)
ln -sf /usr/share/zoneinfo/$TZuser /etc/localtime

hwclock --systohc

echo "LANG=en_US.UTF-8" >> /etc/locale.conf
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "en_US ISO-8859-1" >> /etc/locale.gen
locale-gen

pacman --noconfirm dialog -Syu networkmanager networkmanager-runit network-manager-applet
ln -s  /etc/runit/sv/NetworkManager /run/runit/service/NetworkManager

pacman --noconfirm dialog -Syu grub && grub-install --target=i386-pc /dev/sda && grub-mkconfig -o /boot/grub/grub.cfg

exit
