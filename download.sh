#!/bin/bash
# Copyright (c) 2017, MIT Licensed, Medicine Yeh

SCRIPT_PATH="$(dirname "${BASH_SOURCE[0]}")"
IMAGE_DIR="$SCRIPT_PATH/guest-images"
COLOR_RED='\033[1;31m'
COLOR_GREEN='\033[1;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[1;34m'
NC='\033[0m'


# Format: [OUTPUT PATH]/<RENAMED COMPRESSED FILE NAME>
# Where the OUTPUT PATH is optional since the compressed file might already contain
# the directory hierarchy tree, i.e., release version or vendor/provider names.
files=('dev/testimage-v1.3.tar.gz'
       'dev/beta-software')

links=('https://github.com/MedicineYeh/microzed-image/archive/v1.3.tar.gz'
       'git+https://github.com/MedicineYeh/beta-software-wrapper')

sha256sums=('6439c480e97ea1763ec62bfc6611db275f3a995743a391954b47cb5727670fe1'
            '')

#######################################
# Check the sha256sum and return 0 when succeed.
# Always return 0 if the first argument is an empty string.
# Globals:
#   None
# Arguments:
#   <FILE PATH>
#   <SHA256SUM>
# Returns:
#   succeed:0 / failed:1
#######################################
function check_sha256() {
    local sum=$(sha256sum -b "$1" | cut -d " " -f1)
    [[ "" == "$2" ]] && return 0     # return success if the target comparison is empty
    [[ "$sum" == "$2" ]] && return 0 # success
    return 1 # fail
}

function unfold_file() {
    local file_name=$(basename "$1")
    local dir_name=$(dirname "$1")

    mkdir -p "$dir_name"
    cd $dir_name
    echo -e "${COLOR_GREEN}decompress file $1${NC}"
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
}

function main() {
    local index=0

    mkdir -p "$IMAGE_DIR"
    cd "$IMAGE_DIR"
    # Download all links/files
    for file_name in "${files[@]}"; do
        local link="${links[${index}]}"
        mkdir -p "$(dirname "$file_name")" # Create target directory for downloading

        if [[ "$link" == "git+"* ]]; then
            # Download as git
            link="${link##git+}"  # Remove git+ word
            [[ ! -d "$file_name" ]] && git clone --depth 10 "$link" "$file_name"
        else
            # Download as HTTP
            [[ ! -f "${file_name}" ]] && wget "$link" -O "$file_name"
            if $(check_sha256 $file_name ${sha256sums[${index}]}); then
                (unfold_file $file_name) # Use () to prevent directory changes
            else
                echo -e "${COLOR_RED}Fatal: The file '$file_name' sha256sum does not match!!${NC}"
            fi
        fi
        index+=1
    done
    cd - > /dev/null # Mute the folder change message
}

main

exit 0
