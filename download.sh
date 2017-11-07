#!/bin/bash
# Copyright (c) 2017, MIT Licensed, Medicine Yeh

SCRIPT_PATH="$(dirname "${BASH_SOURCE[0]}")"
IMAGE_DIR="$SCRIPT_PATH/guest-images"

# Format: [OUTPUT PATH]/<RENAMED COMPRESSED FILE NAME>
# Where the OUTPUT PATH is optional since the compressed file might already contain
# the directory hierarchy we need, i.e., release version.
files=('dev/testimage-v1.2.tar.gz')

links=('https://github.com/MedicineYeh/microzed-image/archive/v1.2.tar.gz')

sha256sums=('a925aa25c9a631777a127d567ac1f624ba6d06c65bd4570015c1114f7bfdac4e')

function check_sha256() {
    local sum=$(sha256sum -b "$1" | cut -d " " -f1)
    [[ "" == "$2" ]] && return 0     # return success if the target comparison is empty
    [[ "$sum" == "$2" ]] && return 0 # success
    return 1 # fail
}

function unfold_file() {
    local file_name=$(basename "$1")
    local dir_name=$(dirname "$1")
    local COLOR_GREEN='\033[1;32m'
    local COLOR_BLUE='\033[1;34m'
    local NC='\033[0m'

    cd $dir_name
    echo -e "${COLOR_GREEN}decompress file $file_path${NC}"
    case "$file_name" in
        *.tar.gz|*.tgz) tar zxf "$file_name" ;;
        *.tar.bz2|*.tbz|*.tbz2) tar xjf "$file_name" ;;
        *.tar.xz|*.txz) tar --xz --help &> /dev/null && tar --xz -xf "$file_name" || xzcat "$file_name" | tar xf - ;;
        *.tar.zma|*.tlz) tar --lzma --help &> /dev/null && tar --lzma -xf "$file_name" || lzcat "$file_name" | tar xf - ;;
        *.tar) tar xf "$file_name" ;;
        *.gz) gunzip "$file_name" ;;
        *.bz2) bunzip2 "$file_name" ;;
        *.xz) unxz "$file_name" ;;
        *.lzma) unlzma "$file_name" ;;
        *.Z) uncompress "$file_name" ;;
        *.zip|*.war|*.jar|*.sublime-package|*.ipsw|*.xpi|*.apk) unzip "$file_name" ;;
        *.rar) unrar x -ad "$file_name" ;;
        *.7z) 7za x "$file_name" ;;
        * ) echo -e "${COLOR_BLUE}fail to decompress file $file_path${NC}" ;;
    esac
    cd -
}

function main() {
    local COLOR_RED='\033[1;31m'
    local NC='\033[0m'
    local index=0

    mkdir -p "$IMAGE_DIR"
    cd "$IMAGE_DIR"
    for file_name in "${files[@]}"; do
        local dir_name=$(dirname "$file_name")
        mkdir -p $dir_name # Create directory
        [[ ! -f "${file_name}" ]] && wget "${links[${index}]}" -O "$file_name"
        if $(check_sha256 $file_name ${sha256sums[${index}]}); then
            (unfold_file $file_name) # Use () in case the dir being wrong
        else
            echo -e "${COLOR_RED}Fatal: The file '$file_name' sha256sum does not match!!${NC}"
        fi
        index+=1
    done
    cd - > /dev/null # Mute the folder change message
}

main

exit 0
