# This will be the location of settings.sh
if [[ -n "$ZSH_VERSION" ]]; then # assume Zsh
    AXIOM_HOME="$(readlink -f "$(dirname "$0")")"
elif [[ -n "$BASH_VERSION" ]]; then # assume Bash
    AXIOM_HOME="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")")"
fi
export IMAGE_DIR="$AXIOM_HOME/guest-images"
# The name of ROOTFS_DIR must be rootfs for safety.
export ROOTFS_DIR="$(readlink -f "${IMAGE_DIR}/.rootfs")"
export VIRT_ROOT_DIR="${AXIOM_HOME}/virt-root"
export RUN_QEMU_SCRIPT_PATH="${AXIOM_HOME}"
