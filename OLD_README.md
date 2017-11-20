These scripts are currently tailored for being run on Ubuntu/Debian based systems as they acquire dependencies through apt-get.


# axiom-beta-qemu
QEMU emulation of the AXIOM Beta hardware / software

These scripts will help you to run the AXIOM Beta OS on QEMU.

To get started, make sure you have a good internet connection
and at least (!) 25 GB of free space, then clone the repository
and follow the steps below.

    git clone https://github.com/apertus-open-source-cinema/axiom-beta-qemu
    cd axiom-beta-qemu

## Step 1: Build and Install QEMU
You will need to install QEMU from the Xilinx repository;
run this script at the command prompt:

    ./build_qemu.sh

See http://www.wiki.xilinx.com/QEMU for additional info.
After QEMU is built, you will have to provide the system password to install it.

## Step 2: Build the Linux kernel from Xilinx

Note: You need to install either kernel 4.6.0 (recommended)
or kernel 4.9.0 (not fully working yet).

### Step 2A: Build Xilinx Linux kernel 4.6.0

To download and build this kernel, run:

    ./build_kernel4.6.0.sh

As we tested, kernel 4.6.0 works properly on QEMU.

### Step 2B: Build Xilinx Linux kernel 4.9.0

This will download the latest (git) version of the Xilinx Linux kernel.
However, at the moment, this kernel verion will not run on QEMU properly.
If you are confident you can fix it, run:

    ./build_kernel4.9.0.sh

## Step 3: Download AXIOM Beta image
To download the AXIOM Beta image, run the following script:

```
wget http://vserver.13thfloor.at/Stuff/AXIOM/BETA/beta_20170109.dd.xz
wget http://vserver.13thfloor.at/Stuff/AXIOM/BETA/devicetree.dtb
wget http://vserver.13thfloor.at/Stuff/AXIOM/BETA/u-boot
```

Note: This will download around 3.7GB.

## Step 4: Run QEMU

This will start the Axiom BETA firmware in QEMU.

    ./start_qemu.sh

Wait until you get the login prompt and... start hacking.

## Next steps

- wiki page: [AXIOM_Beta_QEMU](https://wiki.apertus.org/index.php/AXIOM_Beta_QEMU)
- add examples (using GDB, debugging devices etc)
- create the Beta image from scratch
- emulate the hardware devices present in the Beta
