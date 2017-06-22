#!/bin/bash

# download qemu source
echo "	****Downloading qemu source****"
git clone git://github.com/Xilinx/qemu.git

cd qemu

# install dependencies
echo "	****Installing dependencies****"
sudo apt install libglib2.0-dev libgcrypt20-dev zlib1g-dev autoconf automake libtool bison flex

# get the submodules
echo "	****Getting sub modules****"
git submodule update --init pixman dtc

# configuring the QEMU
echo "	****Configuring QEMU****"
./configure --target-list="aarch64-softmmu,microblazeel-softmmu" --enable-fdt --disable-kvm --disable-xen

echo "	****Installing QEMU****"
# make
make -j4
#make

# install
sudo make install

# go back to folder
cd ..

echo "	****QEMU Installation Complete****"
