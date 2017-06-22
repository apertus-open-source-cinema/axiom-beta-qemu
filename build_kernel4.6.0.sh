#!/bin/bash

echo "	****Cheking for requirements****"
# requirements Ubuntu
sudo apt-get install build-essential gcc-arm-linux-gnueabi libglib2.0-dev zlib1g-dev

echo "	****Getting the source****"
# get the git repo
https://github.com/Xilinx/linux-xlnx.git

# go into source folder
cd linux-xlnx

echo "	****Getting older version****"
# check for older version
git checkout tags/xilinx-v2016.4 -b xilinx-v2016.4

echo "	****Getting config file****"
# for kernel 4.6.x
wget http://vserver.13thfloor.at/Stuff/AXIOM/BETA/kernel-4.6.0-xilinx-00016-gb49271f.config

# rename to .config
mv kernel-4.6.0-xilinx-00016-gb49271f.config .config

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
