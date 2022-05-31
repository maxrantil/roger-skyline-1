# continue from deploy.sh

TZuser=$(cat tzfinal.tmp)
ln -sf /usr/share/zoneinfo/$TZuser /etc/localtime
rm tzfinal.tmp

hwclock --systohc

echo "LANG=en_US.UTF-8" >> /etc/locale.conf
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "en_US ISO-8859-1" >> /etc/locale.gen
locale-gen

pacman --noconfirm dialog -Syu networkmanager networkmanager-runit network-manager-applet
ln -s  /etc/runit/sv/NetworkManager /run/runit/service/NetworkManager

pacman --noconfirm dialog -Syu grub && grub-install --target=i386-pc /dev/sda && grub-mkconfig -o /boot/grub/grub.cfg

spass1=$(dialog --no-cancel --title "Change root password" --passwordbox "Enter a new root password." 10 60 3>&1 1>&2 2>&3 3>&1)
spass2=$(dialog --no-cancel --title "Change root password" --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
while ! [ "$spass1" = "$spass2" ]; do
	unset spass2
	spass1=$(dialog --no-cancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
	spass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
done;
echo -e "$spass1\n$spass1" | passwd

exit
