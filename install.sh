#!/bin/bash
# Copyright (c) 2017, MIT Licensed, Medicine Yeh

SCRIPT_DIR=$(readlink -f "$(dirname "${BASH_SOURCE[0]}")")
COLOR_RED='\033[1;31m'
COLOR_GREEN='\033[1;32m'
COLOR_YELLOW='\033[1;33m'
NC='\033[0;00m'

function install_debian_packages() {
    echo -e "#    ${COLOR_GREEN}Installing packages for Debian...${NC}"

    local BASIC_DEPS=(
        sudo
        wget
        git
        e2fsprogs
        mtools
        dosfstools
        bc
        python
        openssl
        expect
        fakeroot
        fakechroot
        fuse
        libfuse-dev
        pkg-config
        autopoint
        rsync
        qemu-user-static
        binfmt-support
    )
    local QEMU_DEPS=(
        # Required packages
        libglib2.0-dev
        libfdt-dev
        libpixman-1-dev
        zlib1g-dev
        # Additional packages
        libnfs-dev
        libiscsi-dev
        libgtk2.0-dev
        libaio-dev
        libgcrypt20-dev
        # Others
        autoconf
        automake
        libtool
        flex
        bison
    )
    local EXTRA_DEPS=(
        qemu-user-static
        boxes
    )
    apt-get -y -qq update

    # Define which developer package set should be installed
    local BASE_DEVEL=build-essential
    # Separate the developer package installation! Sometimes it might fail.
    apt-get -y install $BASE_DEVEL
    [[ $? != 0 ]] && print_message_and_exit "Install $BASE_DEVEL"
    apt-get -y install ${BASIC_DEPS[@]}
    [[ $? != 0 ]] && print_message_and_exit "Install BASIC_DEPS"
    apt-get -y install ${QEMU_DEPS[@]}
    [[ $? != 0 ]] && print_message_and_exit "Install QEMU_DEPS"
    apt-get -y install ${EXTRA_DEPS[@]}
    [[ $? != 0 ]] && print_message_and_exit "Install EXTRA_DEPS"
}

function install_arch_packages() {
    echo -e "#    ${COLOR_GREEN}Installing packages for ArchLinux...${NC}"
    # Available in AUR: boxes dh-autoreconf

    # NOTE: Do not use base-devel directly!!!!!! It's conflict with gcc-libs-multilib
    local BASIC_DEPS=(
        sudo
        wget
        git
        e2fsprogs
        mtools
        dosfstools
        bc
        python
        python2
        openssl
        expect
        fakeroot
        fakechroot
        fuse
        fuse3
        fuse-common
        pkg-config
        rsync
    )
    local QEMU_DEPS=(
        # Required packages
        glib2
        dtc
        pixman
        zlib
        # Additional packages
        libnfs
        libiscsi
        gtk2
        libaio
        libgcrypt
        # Others
        autoconf
        automake
        libtool
        flex
        bison
    )
    local EXTRA_DEPS=(
        qemu
    )
    local AUR_DEPS=(
        qemu-user-static
        binfmt-support
        boxes
    )
    # Define which developer package set should be installed
    local BASE_DEVEL=base-devel

    # ArchLinux is a rolling release distribution, thus updating database is required.
    pacman -Syy

    # Separate the developer package installation! Sometimes it might fail.
    pacman --noconfirm -S $BASE_DEVEL
    [[ $? != 0 ]] && print_message_and_exit "Install BASE_DEVEL"
    pacman --noconfirm -S ${BASIC_DEPS[@]}
    [[ $? != 0 ]] && print_message_and_exit "Install BASIC_DEPS"
    pacman --noconfirm -S ${QEMU_DEPS[@]}
    [[ $? != 0 ]] && print_message_and_exit "Install QEMU_DEPS"
    pacman --noconfirm -S ${EXTRA_DEPS[@]}
    [[ $? != 0 ]] && print_message_and_exit "Install EXTRA_DEPS"

    local flag_ok=1
    for pkg in "${AUR_DEPS[@]}"; do
        ! $(pacman -Qs $pkg 2>&1 > /dev/null) && flag_ok=0
    done
    if [[ $flag_ok == 0 ]]; then
        echo -e "\nPlease install the following AUR packages by hand!!\n"
        echo -e "    ${AUR_DEPS[@]}\n\n"
    fi
}

function install_centos_packages() {
    echo -e "#    ${COLOR_GREEN}Installing packages for CentOS/Fedora...${NC}"

    # NOTE: Do not use base-devel directly!!!!!! It's conflict with gcc-libs-multilib
    local BASIC_DEPS=(
        sudo
        wget
        git
        e2fsprogs
        mtools
        dosfstools
        bc
        python
        openssl
        expect
        fakeroot
        fakechroot
        fuse
        libfuse-devel
        pkg-config
        rsync
        qemu-user-static
        binfmt-support
    )
    local QEMU_DEPS=(
        # Required packages
        glib2-devel
        libfdt-devel
        pixman-devel
        zlib-devel
        # Additional packages
        # libnfs-devel is missing
        libiscsi-devel
        gtk2-devel
        libaio-devel
        libgcrypt-devel
        # Others
        autoconf
        automake
        libtool
        flex
        bison
    )
    local EXTRA_DEPS=(
        libcap-devel
        qemu
    )
    yum -y update

    # Define which developer package set should be installed
    local BASE_DEVEL=development
    # Separate the developer package installation! Sometimes it might fail.
    yum -y groupinstall $BASE_DEVEL
    [[ $? != 0 ]] && print_message_and_exit "Install $BASE_DEVEL"
    yum -y install ${BASIC_DEPS[@]}
    [[ $? != 0 ]] && print_message_and_exit "Install BASIC_DEPS"
    yum -y install ${QEMU_DEPS[@]}
    [[ $? != 0 ]] && print_message_and_exit "Install QEMU_DEPS"
    yum -y install ${EXTRA_DEPS[@]}
    [[ $? != 0 ]] && print_message_and_exit "Install EXTRA_DEPS"
}


#######################################
# Simply print messages and exit with error number 1.
# This is used to indicate user what happened in the build system.
# Globals:
#   None
# Arguments:
#   <MESSAGE>
# Returns:
#   None
#######################################
function print_message_and_exit() {
    COLOR_YELLOW='\033[1;33m'
    NC='\033[0m'

    echo "Something went wrong?"
    echo -e "Possibly related to ${COLOR_YELLOW}${1}${NC}"
    exit 1
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

function install_arm_compiler() {
    # Download arm-linux-gnueabi-gcc if not exists
    if ! command_exist arm-linux-gnueabi-gcc || ! command_exist arm-linux-gnueabi-g++; then # Not found
        echo -e "#    ${COLOR_GREEN}Downloading and installing ARM compiler...${NC}"
        local file_path="/tmp/gcc-linaro-4.9-gnueabi.tar.xz"
        local dir_path="/opt/gcc-linaro-4.9-gnueabi"
        local link="https://releases.linaro.org/components/toolchain/binaries/4.9-2017.01/arm-linux-gnueabi/gcc-linaro-4.9.4-2017.01-x86_64_arm-linux-gnueabi.tar.xz"

        [[ ! -f "$file_path" ]] && wget "$link" -O "$file_path"
        mkdir -p "$dir_path"
        echo -e "${COLOR_GREEN}decompress file $file_path${NC}"
        tar -xf "$file_path" -C "$dir_path" --strip-components 1
        echo -e "${COLOR_YELLOW}Please copy and paste the following line to your ~/.bashrc or ~/.zshrc${NC}"
        echo "export PATH=\$PATH:${dir_path}/bin"
        echo -e "\n\n"
        # Make it temporarily work for this script.
        export PATH=${dir_path}/bin:$PATH
    fi
}

# Use package manager to identify the operating systems
if command_exist apt-get; then
    echo "Debian, Mint, Ubuntu"
    install_debian_packages
elif command_exist pacman; then
    echo "ArchLinux"
    install_arch_packages
elif command_exist yum; then
    echo "CentOS, Fedora"
    install_centos_packages
fi

install_arm_compiler

exit 0
