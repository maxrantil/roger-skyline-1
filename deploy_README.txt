## before you can run the deploy.sh script:
## log in as 'root' with password 'artix'
###
root
artix

curl https://raw.githubusercontent.com/maxrantil/roger-skyline-1/master/deploy.sh > deploy.sh
bash deploy.sh

## on a fresh install activate internet with:
###
ln -s /etc/runit/sv/NetworkManager /run/runit/service/NetworkManager

curl https://raw.githubusercontent.com/maxrantil/roger-skyline-1/master/setup.sh > setup.sh
