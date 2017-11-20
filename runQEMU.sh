#!/bin/bash
# Copyright (c) 2017, MIT Licensed, Medicine Yeh

SCRIPT_PATH="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")")"
IMAGE_DIR="$SCRIPT_PATH/guest-images"
#Use PATH to automatically solve the binary path problem.
export PATH=$(pwd)/aarch64-softmmu/:$SCRIPT_PATH/qemu-xilinx/build/aarch64-softmmu/:$PATH
export QEMU_ARM=qemu-system-aarch64
export QEMU_X86=qemu-system-x86_64
QEMU_ARGS=()

# QEMU_ARGS+=(-drive if=sd,driver=raw,cache=writeback,file=$IMAGE_DIR/data.ext3)

# Debug traces
#QEMU_ARGS+=(-trace enable=true,events=/tmp/events-vfio)
#QEMU_ARGS+=(-mem-path /dev/hugepages)

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
    echo "Image List:"
    local image_list=( $(cd "${IMAGE_DIR}" && find -type f -name "runQEMU.sh" | xargs dirname) )
    for img in "${image_list[@]}"; do
        echo "${img##*./}"
    done
}

function open_tap() {
    if [[ $(sudo -n ip 2>&1|grep "Usage"|wc -l) == 0 ]] \
        || [[ $(sudo -n brctl 2>&1|grep "Usage"|wc -l) == 0 ]]; then
        echo -e "\033[1;37m#You can add the following line into sudoer to save your time\033[0;00m"
        echo -e "\033[1;32m$(whoami) ALL=NOPASSWD: /usr/bin/ip, /usr/bin/brctl\033[0;00m"
    fi
    sudo ip tuntap add tap0 mode tap user $(whoami)
}

function generate_random_mac_addr() {
    if [ ! -f $SCRIPT_PATH/.macaddr ]; then
        printf -v macaddr \
            "52:54:%02x:%02x:%02x:%02x" \
            $(( $RANDOM & 0xff)) $(( $RANDOM & 0xff )) $(( $RANDOM & 0xff)) $(( $RANDOM & 0xff ))
        echo $macaddr > $SCRIPT_PATH/.macaddr
    fi
    MAC_ADDR=$(cat $SCRIPT_PATH/.macaddr)
}

while [[ "$1" != "" ]]; do
    # Parse arguments
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

if [ -z "$image_path" ]; then
    # No device name after options
    print_help
    exit 1
fi

# Target is a file, capture its directory instead.
image_path_d="$(dirname "$image_path")"

# Try relative path first
ROUTES=()
if [[ -r "$image_path" ]]; then
    ROUTES+=("$image_path/runQEMU.sh")
    ROUTES+=("$image_path_d/runQEMU.sh")
fi
# Try absolute path
ROUTES+=("$IMAGE_DIR/$image_path/runQEMU.sh")
ROUTES+=("$IMAGE_DIR/$image_path_d/runQEMU.sh")
for path in "${ROUTES[@]}"; do
    [[ -r "$path" ]] && QEMU="$path" && break;
done

if [[ ! -r "$QEMU" ]]; then
    echo "Cannot find script runQEMU.sh in \"$image_path\"."
    exit 1
fi

# Execute QEMU
$QEMU "${QEMU_ARGS[@]}"
