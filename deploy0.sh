#!/bin/bash

# 4 partitions with swap

sudo fdisk /dev/sda
echo 'n'
echo 'p'
echo -ne '\n'
echo -ne '\n'
echo '+512M'
echo 'n'
echo 'p'
echo -ne '\n'
echo -ne '\n'
echo '+2G'
echo 'n'
echo 'p'
echo -ne '\n'
echo -ne '\n'
echo '+4.2G'
echo 'n'
echo 'p'
echo -ne '\n'
echo -ne '\n'
echo -ne '\n'
echo 'w'
sudo mkfs.ext4 -L BOOT /dev/sda1
sudo mkfs.ext4 -L ROOT /dev/sda3
sudo mkfs.ext4 -L HOME /dev/sda4
sudo mkswap -L SWAP /dev/sda2
sudo swapon /dev/sda2/SWAP
sudo mount /dev/sda3/ROOT /mnt
sudo mkdir /mnt/home
sudo mkdir /mnt/boot
sudo mount /dev/sda1/BOOT /mnt/boot
sudo mount /dev/sda4/HOME /mnt/home

