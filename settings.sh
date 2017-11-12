# This will be the location of settings.sh
export SCRIPT_PATH=$(readlink -f $(dirname "${BASH_SOURCE[0]}"))
export IMAGE_DIR="$SCRIPT_PATH/guest-images"
# The name of ROOTFS_DIR must be rootfs for safety.
export ROOTFS_DIR="$(readlink -f "${IMAGE_DIR}/.rootfs")"
