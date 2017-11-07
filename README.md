[![Build Status](https://travis-ci.org/MedicineYeh/axiom-beta-env.svg?branch=master)](https://travis-ci.org/MedicineYeh/axiom-beta-env)

# axiom-beta-env
An apertus° AXIOM-beta execution environment for both developer/user

Note: This is a proposal version, which means it's still in alpha phase and might have some minor bugs and dirty codes.

# Execute anywhere
All the scripts are designed to be run at any directory. Feel free and safe to run all the scripts in any folder.

# Instructions
1. `sudo ./install.sh`
2. `./prepare_all.sh`
3. `./download.sh`
4. `./guest-images/dev/microzed-image-1.2/build.sh`
5. `./run_image.sh dev/microzed-image-1.2`

NOTE: If you fail on command not found or any problem, try `source ./install_command.sh` and then do it again. This will force system using the binaries comes with this repo.

# AXIOM command (shell function)
1. `source ./install_command.sh`
2. `axiom image list`
3. `axiom image pull dev/microzed-image-1.2@/p2/etc/`
4. `axiom qemu dev/microzed-image-1.2`

# AXIOM command completion
Completion system is available for `axiom`, `image_manager.sh` and `runQEMU.sh`.
Run `source ./install_command.sh` for registering the completion functions.

``` zsh
$ ./image_manager.sh <TAB>
list   -- List all existing images
push   -- Push a file/folder into image
pull   -- Pull a file/folder from image
ls     -- List files in image folder
rm     -- Remove file/folder from image
mkdir  -- Make a folder in image
--help  -h  -- Display help message and information of usage.
```

## You can also tab all the way through the file system in image
``` zsh
$ axiom image push README.md dev/microzed-image-1.2@/etc/<TAB>
rch-release      fstab             iproute2/         login.defs        modprobe.d/       pacman.d/         resolvconf.conf   systemd/        
bash.bash_logout  gai.conf          iptables/         logrotate.conf    modules-load.d/   pam.d/            rpc               tmpfiles.d/     
bash.bashrc       group ..................
```
