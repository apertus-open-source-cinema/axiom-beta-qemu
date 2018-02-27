#!/bin/bash
# Copyright (c) 2017, MIT Licensed, Medicine Yeh

SCRIPT_DIR=$(readlink -f "$(dirname "${BASH_SOURCE[0]}")")
source "${SCRIPT_DIR}/settings.sh"
COLOR_RED='\033[1;31m'
COLOR_GREEN='\033[1;32m'
COLOR_YELLOW='\033[1;33m'
NC='\033[0;00m'

# Make the virtual root directory temporarily work in this tty session
export PATH="${VIRT_ROOT_DIR}/bin":"${VIRT_ROOT_DIR}/sbin":$PATH:/opt/gcc-linaro-4.9-gnueabi/bin

#######################################
# Compare two version numbers (greater than)
# Globals:
#   None
# Arguments:
#   <First version number>
#   <Second version number>
# Returns:
#   true: First number is greater than the second number
#######################################
function version_gt() {
    test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"
}

#######################################
# Get response from user, the response is limited to y/n.
# It will continue reading until user give y(Y)/n(N).
# Globals:
#   None
# Arguments:
#   <Message to user>
#   <Default response when user hit ENTER directly>
# Returns:
#   None
# Echos (string):
#   The response from user
#######################################
function ask_response()
{
    while true; do
        read -p "${1}`echo $'\ndefault '`[${2}]?" yn
        case $yn in
            [Yy]* ) echo "y"; break;;
            [Nn]* ) echo "n"; break;;
            "" ) echo "$2"; break;;
        esac
    done
}

#######################################
# Check whether the command exist in a safe way
# Globals:
#   None
# Arguments:
#   <command>
# Returns:
#   0: found, 1: NOT found
#######################################
function command_exist() {
    command_found=$(command -v "$1" 2> /dev/null)
    if [[ "$command_found" == "" ]]; then
        return 1 # NOT found
    else
        return 0 # Found
    fi
}

#######################################
# Print useful message when something goes wrong and exit the script.
# Globals:
#   None
# Arguments:
#   <Message to user>
# Returns:
#   None
#######################################
function print_message_and_exit() {
    echo "Something went wrong?"
    echo -e "Possibly related to ${COLOR_YELLOW}${1}${NC}"
    exit 4
}

#######################################
# Initialize the git submodules and other git repositories of this project.
#######################################
function init_git(){
    cd "$SCRIPT_DIR"
    local git_version=$(git version | cut -f 3 -d " ")

    if version_gt $git_version 2.14.0; then
        # Shallow clone to save time
        git submodule update --init --depth 10
    else
        # Old git version does not support shallow clone in some cases
        # Read more: https://stackoverflow.com/a/17692710/8323343
        git submodule update --init
    fi
    [[ $? != 0 ]] && print_message_and_exit "git submodule"
}

#######################################
# Configure and compile the QEMU/Xilinx for emulating Zedboard/MicroZed.
#######################################
function prepare_xilinx_qemu() {
    echo -e "#    ${COLOR_GREEN}Prepare Xilinx qemu${NC}"

    cd "$SCRIPT_DIR/qemu-xilinx"
    git submodule update --init pixman dtc
    # Reset all the changes made before (useful when applying patches).
    git reset --hard
    # Apply patches to fix bugs and compatibilities.
    git apply ../patches/*

    # Create build directory for the emulator
    mkdir -p "$SCRIPT_DIR/qemu-xilinx/build"
    # Configure only when this is the first time to build. No re-configuring required.
    cd "$SCRIPT_DIR/qemu-xilinx/build"
    if [[ ! -f ./config-host.mak ]]; then
        # Add gcc flags to prevent errors when compiling
        local cc_version=$(cc --version | head -n 1 | cut -f 3 -d " ")
        local extra_c_flags=''
        if version_gt $cc_version 7.0.0; then
            extra_c_flags='--extra-cflags=-Wformat-truncation=0'
        fi

        # Configure with python2 (important!)
        ../configure \
            '--python=python2' \
            '--enable-fdt' '--disable-kvm' '--disable-xen' \
            $extra_c_flags \
            '--target-list=aarch64-softmmu'
        [[ $? != 0 ]] && print_message_and_exit "QEMU configure script"
    fi
    # Build QEMU/Xilinx
    make -j$(nproc)
    [[ $? != 0 ]] && print_message_and_exit "QEMU make"
}

#######################################
# Build and install 3rd-party commnads to local(user).
# Some commands are listed here because of the version of those commands
# are too old on some OS distributions.
#######################################
function prepare_external() {
    echo -e "#    ${COLOR_GREEN}Prepare external tools${NC}"

    # Prepare the install directory for the commnads
    mkdir -p "${VIRT_ROOT_DIR}/bin" "${VIRT_ROOT_DIR}/sbin"

    # MBRFS is a fuse-based command for mounting MBR partitioned image.
    if ! command_exist mbrfs; then
        cd "${SCRIPT_DIR}/external/mbrfs"
        make
        [[ $? != 0 ]] && print_message_and_exit "make external/mbrfs"
        cp "${SCRIPT_DIR}/external/mbrfs/mbrfs" "${VIRT_ROOT_DIR}/sbin/mbrfs"
    fi
    # ext4fuse is a fuse-based command for mounting e2fs (ext2, ext3, ext4) file system.
    if ! command_exist ext4fuse; then
        cd "${SCRIPT_DIR}/external/ext4fuse"
        make
        [[ $? != 0 ]] && print_message_and_exit "make external/ext4fuse"
        cp "$SCRIPT_DIR/external/ext4fuse/ext4fuse" "${VIRT_ROOT_DIR}/sbin/ext4fuse"
    fi
    # mkfs.ext4 is a sub-command of e2fsprogs for building images without actually mounting them.
    # Though it exists in all OS distributions, a recent version of e2fsprogs is required.
    if [[ "$(mkfs.ext4 2>&1 | grep root-directory)" == "" ]]; then
        # System mkfs.ext4 does not support root-directory option
        mkdir -p "${SCRIPT_DIR}/external/e2fsprogs/build"
        cd "${SCRIPT_DIR}/external/e2fsprogs/build"
        ../configure --prefix="$VIRT_ROOT_DIR"
        make -j$(nproc)
        make install
    fi
    # TODO Check what type of sfdisk would cause a problem, at least ArchLinux works
    # sfdisk is a script-based command for image partitioning.
    # Though it exists in all OS distributions, a recent version of sfdisk is required.
    if ! command_exist pacman; then
        # System sfdisk does not support creating MBR partition table properly
        mkdir -p "${SCRIPT_DIR}/external/util-linux/build"
        cd "${SCRIPT_DIR}/external/util-linux/build"
        ../autogen.sh
        ../configure --prefix="$VIRT_ROOT_DIR"
        make sfdisk -j$(nproc)
        cp ./sfdisk "${VIRT_ROOT_DIR}/sbin"
    fi
}

#######################################
# Check whether all required binaries are installed for building/running this project.
#######################################
function test_binary_dep() {
    local cmds=(gcc git make wget curl sudo chroot fakeroot rsync)
    cmds+=(arm-linux-gnueabi-gcc arm-linux-gnueabi-g++)

    # Loop through and check commands
    for c in ${cmds[*]}; do
        ! command_exist "$c" && echo -e "Required command ${COLOR_RED}${c}${NC} not found"
    done
}

# A magic option to help facilitate build environment in other projects
if [[ "$1" == "-i" ]]; then
    # Install only, don't build QEMU and other stuffs
    test_binary_dep
    init_git
    prepare_external
    exit 0
fi
test_binary_dep
init_git
prepare_external
prepare_xilinx_qemu

exit 0
