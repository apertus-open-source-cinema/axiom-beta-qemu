if [[ -n "$ZSH_VERSION" ]]; then
    # assume Zsh
    AXIOM_HOME="$(readlink -f "$(dirname "$0")")"
    source "${AXIOM_HOME}/completion-system/zsh_comp.sh"
elif [[ -n "$BASH_VERSION" ]]; then
    # assume Bash
    AXIOM_HOME="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")")"
    source "${AXIOM_HOME}/completion-system/bash_comp.sh"
fi
export RUN_QEMU_SCRIPT_PATH="${AXIOM_HOME}"
export PATH="${AXIOM_HOME}/bin":$PATH
echo "Installed shell function - axiom. The completion of all scripts and axiom command are now available."
echo "\$AXIOM_HOME=${AXIOM_HOME}"

function axiom() {
    task=$1
    # Remove the first 'task' argument
    shift 1
    # Reset flag so that next completion will reload variables
    axiom_update_flag=0

    case $task in
        qemu)
            $RUN_QEMU_SCRIPT_PATH/runQEMU.sh $@
            ;;
        image)
            $RUN_QEMU_SCRIPT_PATH/image_manager.sh $@
            ;;
    esac
}

