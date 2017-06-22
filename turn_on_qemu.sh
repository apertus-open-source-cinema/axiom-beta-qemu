#!/bin/sh

cd AXIOM_Beta_VM

echo "	****TURNING ON QEMU****"

qemu-system-aarch64 -M arm-generic-fdt-7series -machine linux=on -m 1024 -serial /dev/null -serial mon:stdio -nographic -dtb devicetree.dtb -kernel zImage -drive if=sd,format=raw,index=0,file=beta_20170109.dd -boot mode=5 -append "root=/dev/mmcblk0p2 ro rootwait rootfstype=ext4"
