# axiom-beta-qemu
QEMU emulation of the AXIOM Beta hardware / software

This scripts will help you to run AXIOM Beta OS on QEMU.
Follow the following steps to build and run the QEMU.

# Step 1: Build and Installing QEMU 
First you need to build and install the QEMU. For that, go open the terminal on axiom-beta-qemu repo folder and run the following commands.

`chmod +x build_qemu.sh`

`./build_qemu.sh`

Note: This will download QEMU form Xilinx QEMU repo. Therefore you need to have internet conneciton while running this script. Also provide system password to install QEMU.

# Step 2-[A]: Build Xilinx Kernel 4.6.0
Note: You need to follow either Step 2-[A] or 2-[B].
If you are hope to run Kernel 4.6.0, then run this step. If you are hoping to run Kernel4.9.0, then follow step 2-[B]. However, as we tested, Kernel4.6.0 work properly on QEMU.
To build Kernel4.6.0, run following commands on terminal opened in axiom-beta-qemu repo folder.

`chmod +x build_kernel4.6.0.sh`

`./build_kernel4.6.0.sh`
 
Note: This will download Xilinx linux kernel newest verion. Therefore you need to have a good internet connection while running this script.

# Step 2-[B]: Build Xilinx Kernel 4.9.0
Note: You need to follow either Step 2-[A] or 2-[B].
This step will build Xilinx Kernel 4.9.0. How ever at the moment, this kernel verion will not run on QEMU properly. Recomend to use Kernel 4.6.0.

To build Kernel 4.9.0, run following commands on terminal opend in axiom-beta-qemu repo folder.

`chmod +x build_kernel4.9.0.sh`

`./build_kernel4.9.0.sh`

Note: This will download Xilinx linux kernel newest verion. Therefore you need to have a good internet connection while running this script.

# Step 3: Download AXIOM Beta image
To download AXIOM Beta image, run the following commands.

`chmod +x download_axiom_beta_image.sh`

`./download_axiom_beta_image.sh`

Note: This will download arround 3.7GB. Run following commands on terminal opend in axiom-beta-qemu repo folder

# Step 4: Run QEMU
To run the QEMU use the following commands on terminal opend in axiom-beta-qemu repo folder.

`chmod +x turn_on_qemu.sh`

`./turn_on_qemu.sh`

Note: After completing Steps 1,2 and 3 for one time, you don't need to run those steps everytime. By running only step 4 will able to turn on QEMU.
