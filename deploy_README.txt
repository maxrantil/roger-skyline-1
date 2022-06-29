## before you can run the deploy.sh script:
## log in as 'root' with password 'artix'
###
root
artix

## Run the Artix installation script
###
curl https://raw.githubusercontent.com/maxrantil/roger-skyline-1/master/deploy.sh > deploy.sh && sh deploy.sh

## on a fresh install activate internet with:
###
ln -s /etc/runit/sv/NetworkManager /run/runit/service/

## Then run the setup script
###
curl https://raw.githubusercontent.com/maxrantil/roger-skyline-1/master/setup.sh > setup.sh && sh setup.sh
