#!/bin/bash

echo "	****Cheking for requirements****"
# requirements Ubuntu
sudo apt-get install build-essential gcc-arm-linux-gnueabi libglib2.0-dev zlib1g-dev

echo "	****Getting the source****"
# get the git repo
https://github.com/Xilinx/linux-xlnx.git

# go into source folder
cd linux-xlnx

echo "	****Getting config file****"
# for kernel 4.9.x
wget http://vserver.13thfloor.at/Stuff/AXIOM/BETA/kernel-4.9.0-xilinx-00037-g5d029fd.config

# rename to .config
mv kernel-4.9.0-xilinx-00037-g5d029fd.config .config

echo "	****Adding configeration****"
# add config
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- oldconfig

echo "	****Start building kernel****"
# build kernel
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi-

echo "	****Start building modules****"
# build modules 
INSTALL_MOD_PATH=../modules/ make modules_install ARCH=arm

# return to home folder
cd ..

echo "	****Kernel building completed!****"
