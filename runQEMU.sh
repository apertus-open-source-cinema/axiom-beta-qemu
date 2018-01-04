#!/bin/bash
# Copyright (c) 2017, MIT Licensed, Medicine Yeh

SCRIPT_PATH="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/settings.sh"
COLOR_RED='\033[1;31m'
COLOR_GREEN='\033[1;32m'
COLOR_YELLOW='\033[1;33m'
NC='\033[0;00m'

# Use PATH to automatically solve the binary path problem. Export vars to child processes
export PATH=$(pwd)/aarch64-softmmu/:"${SCRIPT_PATH}/qemu-xilinx/build/aarch64-softmmu/":$PATH
export QEMU_ARM=qemu-system-aarch64
export QEMU_X86=qemu-system-x86_64
QEMU_ARGS=()

# Global arguments to all running instances
# QEMU_ARGS+=(-drive if=sd,driver=raw,cache=writeback,file=$IMAGE_DIR/data.ext3)

# Debug traces
#QEMU_ARGS+=(-trace enable=true,events=/tmp/events-vfio)
#QEMU_ARGS+=(-mem-path /dev/hugepages)

#######################################
# Find the location of run script from given relative/absolute path.
# This function will also do simple checks on the script, i.e., executable.
# Globals:
#   None
# Arguments:
#   <Relative/Absolute Path>
# Returns:
#   succeed:0 / failed:1
# Echos:
# The absolute path of the run script.
#######################################
function get_run_script() {
    local image_path="$1"
    # No path specified
    [[ -z "$image_path" ]] && return 1
    # If target is a file and also an executable, use it!!!!
    [[ -f "$image_path" ]] && [[ -x "$image_path" ]] && echo "$image_path" && return 0
    # If target is an file, set var to its directory instead
    [[ -f "$image_path" ]] && image_path="$(dirname "$image_path")"
    # If target is not a directory, return with fail
    [[ ! -d "$image_path" ]] && return 1
    # Everything has been checked to get to this step
    # $image_path is now set to an existing path of where image/runscript resides
    local run_script="${image_path}/runQEMU.sh"
    [[ -r "$run_script" ]] && echo "$run_script" && return 0
    # return 1 when the $run_script is not readable/existing
    return 1
}

function print_help() {
    echo "Usage:"
    echo "       $0 <IMAGE NAME> [OPTIONS]..."
    echo "  Execute QEMU with preset arguments for execution."
    echo ""
    echo "Options:"
    echo "       -net                : Enable networks"
    echo "       -g                  : Use gdb to run QEMU"
    echo "       -gg                 : Run QEMU with remote gdb mode to debug guest program"
    echo "                             Default port: 1234"
    echo ""
    echo "Options to QEMU:"
    echo "       -smp <N>            : Number of cores (default: 1)"
    echo "       -m <N>              : Size of memory (default: 1024)"
    echo "       -snapshot           : Read only guest image"
    echo "       -enable-kvm         : Enable KVM"
    echo "       --drive <PATH>      : Hook another disk image to guest"
    echo "       -mem-path <PATH>    : Use file to allocate guest memory"
    echo "                             ex: -mem-path /dev/hugepages"
    echo "       -trace <....>       : Use QEMU trace API with specified events"
    echo "                             ex: -trace enable=true,events=/tmp/events-vfio"
    echo ""
}

#######################################
# Open tap devices for bridge networks.
#######################################
function open_tap() {
    if [[ $(sudo -n ip 2>&1|grep "Usage"|wc -l) == 0 ]] \
        || [[ $(sudo -n brctl 2>&1|grep "Usage"|wc -l) == 0 ]]; then
        echo -e "\033[1;37m#You can add the following line into sudoer to save your time\033[0;00m"
        echo -e "\033[1;32m$(whoami) ALL=NOPASSWD: /usr/bin/ip, /usr/bin/brctl\033[0;00m"
    fi
    sudo ip tuntap add tap0 mode tap user $(whoami)
}

#######################################
# Generate a random MAC address for the emulated platform.
#######################################
function generate_random_mac_addr() {
    if [ ! -f $SCRIPT_PATH/.macaddr ]; then
        printf -v macaddr \
            "52:54:%02x:%02x:%02x:%02x" \
            $(( $RANDOM & 0xff)) $(( $RANDOM & 0xff )) $(( $RANDOM & 0xff)) $(( $RANDOM & 0xff ))
        echo $macaddr > $SCRIPT_PATH/.macaddr
    fi
    MAC_ADDR=$(cat $SCRIPT_PATH/.macaddr)
}

# Parse arguments
while [[ "$1" != "" ]]; do
    case "$1" in
        "-net" )
            generate_random_mac_addr
            open_tap
            #QEMU_ARGS+=(-net nic,model=virtio,macaddr=$MAC_ADDR -net tap,vlan=0,ifname=tap0)
            QEMU_ARGS+=(-netdev type=tap,id=net0,ifname=tap0,vhost=on)
            QEMU_ARGS+=(-device virtio-net-pci,netdev=net0,mac=$MAC_ADDR)
            shift 1
            ;;
        "-g" )
            # Disable file buffering to get the latest results from output
            # One could also use command 'call fflush({file descriptor})' in gdb
            export LD_PRELOAD=${SCRIPT_PATH}/nobuffering.so
            export RUN_WITH_GDB="gdb --args "
            shift 1
            ;;
        "-gg" )
            QEMU_ARGS+=(-S -gdb tcp::1234)
            shift 1
            ;;
        "-smp" )
            QEMU_ARGS+=(-smp $2)
            shift 2
            ;;
        "-m" )
            QEMU_ARGS+=(-m $2)
            shift 2
            ;;
        "-snapshot" )
            QEMU_ARGS+=(-snapshot)
            shift 1
            ;;
        "-enable-kvm" )
            QEMU_ARGS+=(-enable-kvm)
            shift 1
            ;;
        "--drive" )
            QEMU_ARGS+=(-drive if=sd,driver=raw,cache=writeback,file=$2)
            shift 2
            ;;
        "-mem-path" )
            QEMU_ARGS+=(-mem-path "$2")
            shift 2
            ;;
        "-trace" )
            QEMU_ARGS+=(-trace "$2")
            shift 2
            ;;
        "-h" )
            print_help
            exit 0
            ;;
        "--help" )
            print_help
            exit 0
            ;;
        * )
            image_path="$1"
            shift 1
            ;;
    esac
done

# No device/image name is specified in user arguments
[[ -z "$image_path" ]] && print_help && exit 1
# Try relative path first
QEMU=$(get_run_script "$image_path")
# Try absolute path
[[ -z "$QEMU" ]] && QEMU=$(get_run_script "${IMAGE_DIR}/${image_path}")
[[ -z "$QEMU" ]] && echo "Cannot find script runQEMU.sh in '$image_path'" && exit 1

# Execute QEMU
echo -e "Running '${COLOR_GREEN}${QEMU} ${QEMU_ARGS[@]}${NC}'"
$QEMU "${QEMU_ARGS[@]}"

exit 0
