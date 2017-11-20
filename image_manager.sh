#!/bin/bash
# Copyright (c) 2017, MIT Licensed, Medicine Yeh

SCRIPT_PATH=$(dirname "${BASH_SOURCE[0]}")
IMAGE_DIR="$SCRIPT_PATH/guest-images"
# The name of ROOTFS_DIR must be rootfs for safety.
ROOTFS_DIR="$(readlink -f "${IMAGE_DIR}/.rootfs")"

RED='\033[1;31m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
NC='\033[0m'

export PATH="${SCRIPT_PATH}/bin":$PATH

function find_image_list() {
    local possible_list=$(find "$IMAGE_DIR" \
        -type d \( \
            -name 'rootfs' -o \
            -name "bootfs" -o \
            -name 'linux*' -o \
            -name 'linux-*' -o \
            -name "build" -o \
            -name "package" -o \
            -name "*.fs" \
        \) \
        -prune -o \
        -type f \( \
            -name "ext[1-5]" -o \
            -name "IMAGE.dd" -o \
            -name "*.img" \
        \) -exec file {} \; 2>/dev/null)

    echo "$possible_list"
}

function get_list() {
    local l_list=$(echo "$all_file_list" | grep -e "$1")
    [[ "$l_list" ]] && l_list=$(echo "$l_list" | cut -d ":" -f 1)
    echo "$l_list"
}

all_file_list=$(find_image_list)
cpio_list=$(get_list "ASCII cpio archive")
e2fs_list=$(get_list "Linux .* ext.* filesystem data")
mbr_list=$(get_list "MBR boot sector")

# Input: File name or full path
# Output: The image file path found in the list
function find_image_file_in_list() {
    local tmp=''
    local img_name="$1"

    [[ "$img_name" == "" ]] && echo "" && return 4
    # Convert the results into array type and check if the first match exist
    tmp=($(echo "${cpio_list}" | grep "${img_name}"))
    [[ "${tmp[0]}" != "" ]] && echo "${tmp[0]}" && return 0

    tmp=($(echo "${e2fs_list}" | grep "${img_name}"))
    [[ "${tmp[0]}" != "" ]] && echo "${tmp[0]}" && return 0

    tmp=($(echo "${mbr_list}" | grep "${img_name}"))
    [[ "${tmp[0]}" != "" ]] && echo "${tmp[0]}" && return 0

    echo "" && return 4
}

function pretty_print_list() {
    local list="${1}"

    for f in ${list}; do
        # Get relative path without heading slash
        local name="${f##"${IMAGE_DIR}/"}"
        printf "%-40s  %-20s  %-20s\n" \
               "${name}" \
               $(get_image_type "${f}") \
               $(du -h "${f}" | cut -f1)
    done
}

function image_list() {
    printf "%-40s  %-20s  %-20s\n" 'IMAGE NAME' 'TYPE' 'SIZE'
    pretty_print_list "$cpio_list"
    pretty_print_list "$e2fs_list"
    pretty_print_list "$mbr_list"

    echo "" # Empty line
}

function image_list_update() {
    all_file_list=$(find_image_list)
    cpio_list=$(get_list "ASCII cpio archive")
    e2fs_list=$(get_list "Linux .* ext.* filesystem data")
    mbr_list=$(get_list "MBR boot sector")
}

# Output: "": not found. Others: Types of image
function get_image_type() {
    local tmp=''
    local img_name="$1"

    [[ "$img_name" == "" ]] && echo "" && return 4

    tmp=$(echo "${cpio_list}" | grep "$img_name")
    [[ "$tmp" != "" ]] && echo "CPIO" && return 0

    tmp=$(echo "${e2fs_list}" | grep "$img_name")
    [[ "$tmp" != "" ]] && echo $(get_ext_version "$1") && return 0

    tmp=$(echo "${mbr_list}" | grep "$img_name")
    [[ "$tmp" != "" ]] && echo "MBR" && return 0

    echo "" && return 4
}

# Input: file path
# Output: (Capitalized) ext version string
function get_ext_version() {
    local ff=$(file "$1")
    local type=$(expr "$ff" : '^.*\(ext[0-9]\)')
    echo "${type}" | tr '[:lower:]' '[:upper:]'
}

function extract_cpio() {
    local file_path="$(readlink -f "$1")"
    [[ ! -r "$file_path" ]] && exit 4
    mkdir -p "$ROOTFS_DIR"
    cd "$ROOTFS_DIR"
    [[ "$?" != "0" ]] && exit 4
    echo "Extracting CPIO image..."
    sudo cpio -idu --quiet < "$file_path"
    cd - > /dev/null # Mute the folder change message
}

function build_cpio() {
    local file_path="$(readlink -f "$1")"
    [[ ! -r "$file_path" ]] && exit 4
    cd "$ROOTFS_DIR"
    echo "Compressing CPIO image..."
    sudo find . | sudo cpio -H newc --quiet -o > "$file_path"
    cd - > /dev/null # Mute the folder change message
}

function concatenate_path() {
    local path1="${1%%/}"
    local path2="${2%%/}"
    local out_path="$path1/${path2##/}"
    echo "${out_path}"
}

function copy_file() {
    # Remove the tailing slash
    local from_file="${1%%/}"
    local to_file="${2%%/}"
    local to_dir="$(dirname "$to_file")"

    sudo test ! -r "$from_file" &&
        echo "From File path '$from_file' does not exist" && return 4
    sudo test ! -d "$to_file" && sudo test ! -d "$to_dir" &&
        echo "To File path '$to_dir' does not exist" && return 4

    if [[ -r "$from_file" ]] && [[ -w "$to_file" ]]; then
        # Permission is granted to the current user
        cp -r "$from_file" "$to_file"
    else
        # Use privilege permission
        sudo cp -r "$from_file" "$to_file"
    fi
}

function check_all_paths() {
    local file_path="$1"
    local image_path=$2
    local to_file_path="$3"

    if [[ ! -r "$file_path" ]]; then
        echo -e "${RED}[Fatal] File ${file_path} was not found or cannot be read${NC}"
        exit 4
    fi
    if [[ "$image_path" == "" ]]; then
        echo -e "${RED}[Fatal] Image ${tmp_img_name} was not found${NC}"
        echo "Please specify one of the following:"
        image_list
        exit 4
    fi
    if [[ "$to_file_path" == "" ]]; then
        echo -e "${RED}[Fatal] File path in target image filesystem cannot be empty${NC}"
        exit 4
    fi
    if [[ "${to_file_path:0:1}" == "~" ]]; then
        echo -e "${RED}[Fatal] File path in target image filesystem cannot start with ~/${NC}"
        exit 4
    fi
}

function check_mount_point_clean() {
    sleep 0.1 # Wait for last unmount
    if [[ "$(mount | grep "$ROOTFS_DIR")" != "" ]]; then
        echo -e "${RED}Unexpected error: the last images is still mounted...${NC}"
        echo -e "${RED}Abort${NC}"
        exit 4
    fi
}

function clean_image_dir() {
    if [[ "$(basename "$ROOTFS_DIR")" != ".rootfs" ]]; then
        echo -e "${RED}Name of variable ROOTFS_DIR must be '.rootfs' for safety${NC}"
        echo -e "${YELLOW}Leave '$ROOTFS_DIR' not removed...${NC}"
        return 4
    fi
    echo "Cleaning directory..."
    # Try un-mount if it is a mount point
    mountpoint -q "$ROOTFS_DIR" && sudo umount "$ROOTFS_DIR"
    check_mount_point_clean

    # Remove the whole directory if it is a directory and contains at least one file
    [[ -d "$ROOTFS_DIR" ]] && [[ "$(ls "$ROOTFS_DIR" | wc -l)" != "0" ]] &&
        sudo rm -rf "$ROOTFS_DIR"
    mkdir -p "$ROOTFS_DIR"
}

function mount_mbr() {
    local image_path="$1"
    local readonly_flag="$2"
    local sector_size=$(fdisk -l "$image_path" | grep "Sector size" | sed -e "s/.*://g" | sed -e "s/bytes.*//g")
    # Save current IFS
    SAVEIFS=$IFS
    # Change IFS to new line.
    IFS=$'\n'
    local partitions=($(fdisk -l "$image_path" | grep "Linux\|FAT" | grep -v "swap"))
    # Restore IFS
    IFS=$SAVEIFS
    local p_start=()
    local p_end=()
    local p_name=(p1 p2 p3 p4 p5 p6 p7 p8 p9 p10 p11 p12 p13 p14 p15 p16)
    echo "Sector Size: $sector_size"
    echo "Partitions: (Device  Boot  Start  End Sectors  Size  Id  Type)"
    for p in "${partitions[@]}"; do
        echo "$p"
        if [[ "$(echo "$p" | grep "*")" == "" ]]; then
            local sector_start=$(echo "$p" | awk '{print $2}')
            p_start+=("$sector_start")
            p_end+=($(echo "$p" | awk '{print $3}'))
        else
            local sector_start=$(echo "$p" | awk '{print $3}')
            p_start+=("$sector_start")
            p_end+=($(echo "$p" | awk '{print $4}'))
        fi
    done
    echo ""

    local index=0
    local size_limit=0
    for p in "${partitions[@]}"; do
        echo "mount to ${p_name[$index]}"
        local offset=$(( ${p_start[$index]} * $sector_size ))
        mkdir -p "$ROOTFS_DIR/${p_name[$index]}"
        size_limit=$[ size_limit + ${p_end[$index]} - ${p_start[$index]} ]
        local flags="loop,offset=$offset,sizelimit=$[ $size_limit * 512 ]"
        [[ "$readonly_flag" != "" ]] && flags="ro,$flags"
        sudo mount -o "$flags" "$image_path" "$ROOTFS_DIR/${p_name[$index]}"
        index=$(( $index + 1 ))
    done
}

function mount_image() {
    local image_path="$1"
    local readonly_flag="$2"
    local type=$(get_image_type "$image_path")

    echo "Extracting/Mounting $type image, it requires root privilege to create rootfs"
    sudo echo -e "${YELLOW}Running with root privilege now...${NC}"
    [[ $? != 0 ]] && echo -e "${RED}Abort${NC}" && exit 4

    case "$type" in
    "CPIO")
        clean_image_dir
        extract_cpio "$image_path"
        ;;
    "EXT2" | "EXT3" | "EXT4")
        local extra_options=""
        [[ "$readonly_flag" != "" ]] && extra_options="-o ro,norecovery"
        sudo mount $extra_options "$image_path" "$ROOTFS_DIR"
        ;;
    "MBR")
        mount_mbr "$image_path" "$readonly_flag"
        ;;
    *) echo -e "${RED}[Fatal] unknown type of image${NC}" ;;
    esac
}

function unmount_image() {
    local image_path="$1"
    local type=$(get_image_type "$image_path")

    case "$type" in
    "CPIO")
        build_cpio "$image_path"
        clean_image_dir
        ;;
    "EXT2" | "EXT3" | "EXT4")
        sudo umount "$ROOTFS_DIR"
        ;;
    "MBR")
        local partition_folders=($(ls "$ROOTFS_DIR"))
        for p in "${partition_folders[@]}"; do
            mountpoint -q "$ROOTFS_DIR/$p" && sudo umount "$ROOTFS_DIR/$p"
        done
        ;;
    *) echo -e "${RED}[Fatal] unknown type of image${NC}" ;;
    esac
}

# Input 1: <file> 2: <image name>@<file path>
function push_file_to_image() {
    local file_path="$1"
    local tmp_img_name="${2%%@*}"
    local to_file_path="${2##*@}"
    local image_path="$(find_image_file_in_list "${tmp_img_name}")"

    # Number of input arguments
    [[ ${#*} != 2 ]] && exit 4
    [[ "$2" != *"@"* ]] && echo -e "${RED}Wrong input format${NC}" && exit 4
    echo "Copy file '${file_path}' into image '${image_path##./}' with path '${to_file_path}'"
    echo ""
    check_all_paths "$file_path" "$image_path" "$to_file_path"

    mount_image "$image_path"
    copy_file "$file_path" "$(concatenate_path "$ROOTFS_DIR" "$to_file_path")"
    unmount_image "$image_path"
    echo -e "${GREEN}Succeed${NC}"
}

# Input 1: <image name>@<file path> 2: <file>
function pull_file_from_image() {
    local file_path="$2"
    local tmp_img_name="${1%%@*}"
    local to_file_path="${1##*@}"
    local image_path="$(find_image_file_in_list "${tmp_img_name}")"

    # Number of input arguments
    [[ ${#*} != 2 ]] && exit 4
    [[ "$1" != *"@"* ]] && echo -e "${RED}Wrong input format${NC}" && exit 4
    echo "Copy file '${file_path}' from image '${image_path##./}' with path '${to_file_path}'"
    echo ""
    # Output "file_path" does not need to be check so we pass ".", which always exist
    check_all_paths "." "$image_path" "$to_file_path"

    mount_image "$image_path" "readonly"
    copy_file "$(concatenate_path "$ROOTFS_DIR" "$to_file_path")" "$file_path"
    # Change owner and group of copied files
    sudo test -r "$file_path" && sudo chown -R $(whoami):$(whoami) "$file_path"
    unmount_image "$image_path"
    echo -e "${GREEN}Succeed${NC}"
}

# Input 1: <image name>@<file path>
function rm_file_from_image() {
    local tmp_img_name="${1%%@*}"
    local to_file_path="${1##*@}"
    local image_path="$(find_image_file_in_list "${tmp_img_name}")"
    local full_target_path="$(concatenate_path "$ROOTFS_DIR" "$to_file_path")"

    # Number of input arguments
    [[ ${#*} != 1 ]] && exit 4
    [[ "$1" != *"@"* ]] && echo -e "${RED}Wrong input format${NC}" && exit 4
    echo "Remove file '${to_file_path}' from image '${image_path##./}'"
    echo ""
    # Output "file_path" does not need to be check so we pass ".", which always exist
    check_all_paths "." "$image_path" "$to_file_path"

    mount_image "$image_path"
    if sudo test -r "$full_target_path"; then
        sudo rm -rf "$full_target_path"
    fi
    unmount_image "$image_path"
    echo -e "${GREEN}Succeed${NC}"
}

# Input 1: <image name>@<file path>
function mkdir_to_image() {
    local tmp_img_name="${1%%@*}"
    local to_file_path="${1##*@}"
    local image_path="$(find_image_file_in_list "${tmp_img_name}")"
    local full_target_path="$(concatenate_path "$ROOTFS_DIR" "$to_file_path")"

    # Number of input arguments
    [[ ${#*} != 1 ]] && exit 4
    [[ "$1" != *"@"* ]] && echo -e "${RED}Wrong input format${NC}" && exit 4
    echo "Make a directory '${to_file_path}' in image '${image_path##./}'"
    echo ""
    # Output "file_path" does not need to be check so we pass ".", which always exist
    check_all_paths "." "$image_path" "$to_file_path"

    mount_image "$image_path"
    if [[ -w "$(dirname "$full_target_path")" ]]; then
        mkdir -p "$full_target_path"
    else
        sudo mkdir -p "$full_target_path"
    fi
    unmount_image "$image_path"
    echo -e "${GREEN}Succeed${NC}"
}

# We require root privilege here because some files are visible to root only
# Input 1: <image name>@<file path>
function ls_in_image() {
    local tmp_img_name="${1%%@*}"
    local to_file_path="${1##*@}"
    local image_path="$(find_image_file_in_list "${tmp_img_name}")"
    local full_target_path="$(concatenate_path "$ROOTFS_DIR" "$to_file_path")"

    # Number of input arguments
    [[ ${#*} != 1 ]] && exit 4
    [[ "$1" != *"@"* ]] && echo -e "${RED}Wrong input format${NC}" && exit 4
    echo "List the directory '${to_file_path}' in image '${image_path##./}'"
    echo ""
    # Output "file_path" does not need to be check so we pass ".", which always exist
    check_all_paths "." "$image_path" "$to_file_path"

    mount_image "$image_path" "readonly"
    # We require root privilege here because some files are visible to root only
    sudo ls --color=auto -alh "$full_target_path"
    unmount_image "$image_path"
}

function print_help() {
    echo "Usage:"
    echo "       $0 <OPERATION> [IMAGE NAME] [OPTIONS...]"
    echo "  Do something with disk images for simulation."
    echo ""
    echo "OPERATION:"
    echo "       list                         : List all existing images"
    echo "       push  <PATH> <IMAGE>@<PATH>  : Push a file/folder into image"
    echo "       pull  <IMAGE>@<PATH> <PATH>  : Pull a file/folder from image"
    echo "       ls    <IMAGE>@<PATH>         : List files in image"
    echo "       rm    <IMAGE>@<PATH>         : Remove file/folder from image"
    echo "       mkdir <IMAGE>@<PATH>         : Make a folder in image"
    echo ""

    exit 0
}


[[ ${#*} == 0 ]] && print_help

case "$1" in
"-h" | "--help")
    print_help
    ;;
"list")
    image_list
    ;;
"push")
    [[ ${#*} != 3 ]] && echo "# of arguments is not 2" && exit 4
    push_file_to_image "$2" "$3"
    ;;
"pull")
    [[ ${#*} != 3 ]] && echo "# of arguments is not 2" && exit 4
    pull_file_from_image "$2" "$3"
    ;;
"rm")
    [[ ${#*} != 2 ]] && echo "# of arguments is not 1" && exit 4
    rm_file_from_image "$2"
    ;;
"mkdir")
    [[ ${#*} != 2 ]] && echo "# of arguments is not 1" && exit 4
    mkdir_to_image "$2"
    ;;
"ls")
    [[ ${#*} != 2 ]] && echo "# of arguments is not 1" && exit 4
    ls_in_image "$2"
    ;;
"query")
    case "$2" in
        "image_path_and_type")
            [[ ${#*} != 3 ]] && exit 4
            echo "$(find_image_file_in_list "$3")"
            echo "$(get_image_type "$3")"
            ;;
    esac
    ;;
*)
    echo "Operation '$1' is not available"
    exit 4
    ;;
esac


