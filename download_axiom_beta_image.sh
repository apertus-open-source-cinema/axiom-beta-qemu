#!/bin/sh

echo "	****Downloading Image****"
# download the image
mkdir AXIOM_BETA_VM
cd AXIOM_BETA_VM
wget http://vserver.13thfloor.at/Stuff/AXIOM/BETA/beta_20170109.dd.xz
wget http://vserver.13thfloor.at/Stuff/AXIOM/BETA/devicetree.dtb
wget http://vserver.13thfloor.at/Stuff/AXIOM/BETA/u-boot

echo "	****Extracting Image****"
unxz beta_20170109.dd.xz 

cd ..

cp linux-xlnx/arch/arm/boot/zImage AXIOM_BETA_VM

echo "	****Image is now ready to use****"

