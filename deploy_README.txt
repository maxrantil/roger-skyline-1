# before you can run the deploy.sh script:

# log in as 'root' with password 'artix'

root
artix

pacman -Sy --noconfirm git dialog
pacman -Syu --noconfirm

git clone https://github.com/maxrantil/roger-skyline-1
cd roger-skyline-1
./deploy.sh
