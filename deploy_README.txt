# before you can run the deploy.sh script:

# log in as 'root' with password 'artix'
root
artix

pacman -Sy git --noconfirm dialog
pacman -Syu --noconfirm dialog

git clone https://github.com/maxrantil/roger-skyline-1
cd roger-skyline-1

./deploy.sh
