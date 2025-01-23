#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# CONFIGURATION
###############################################################################
export DEBIAN_FRONTEND=noninteractive

GOVER="1.23.4"
GOTAR="go${GOVER}.linux-amd64.tar.gz"
GOURL="https://go.dev/dl/${GOTAR}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath "$SCRIPT_DIR")"
SYZKALLER_SRC="$REPO_ROOT/syzkaller"
IMAGE_DIR="$REPO_ROOT/debian_image"
DEBIAN_IMAGE_URL="https://raw.githubusercontent.com/google/syzkaller/master/tools/create-image.sh"
LINUX_NEXT_GDRIVE_ID="1H_aNBlJZ9qBLF0gvOflBE3-rou0EEbmT"
REPAIRED_REPRODUCERS_GDRIVE_ID="1fcspm0AISvY57DnxiLitUHjGJS_vvc55"
REPAIRED_BUGS_GDRIVE_ID="1aAuCp_zqdjx7OpXBeniFXR5WZsxhI0Ja"

###############################################################################
# LOGGING FUNCTIONS
###############################################################################
# ANSI color codes
COLOR_RESET="\e[0m"
COLOR_RED="\e[31m"
COLOR_GREEN="\e[32m"
COLOR_YELLOW="\e[33m"
COLOR_BLUE="\e[34m"

log_info() {
    # Print [INFO] in green
    echo -e "${COLOR_GREEN}[INFO]${COLOR_RESET} $*"
}

log_error() {
    # Print [ERROR] in red
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
}

check_command() {
    if ! command -v "$1" &>/dev/null; then
        log_error "Command '$1' not found, please install it first."
        exit 1
    fi
}

###############################################################################
# FUNCTIONS
###############################################################################
enable_venv(){
    # create a python virtual environment
    python3 -m venv venv
    source venv/bin/activate
}

install_gdown() {
    log_info "Ensuring gdown is installed"
    if ! command -v gdown &>/dev/null; then
        # Install gdown without affecting system packages too heavily
        python3 -m pip install gdown
        # Refresh shell hash
        hash -r
        if ! command -v gdown &>/dev/null; then
            log_error "gdown installation failed."
            exit 1
        fi
    fi
    log_info "gdown is installed."
}

run_docker_container(){
    containername="icse25-artifacts"
    image_home="/home/apprunner"

    docker build -t $containername .

    docker ps -aq --filter "name=$containername" | grep -q . && \
        docker stop $containername && docker rm $containername

    docker run -it \
    -v $(pwd)/kernel_images:$image_home/icse25/kernel_images \
    -v $(pwd)/linux-next:$image_home/icse25/linux-next \
    -v $(pwd)/debian_image:$image_home/icse25/debian_image \
    $containername  /bin/bash
}

download_reproducers() {
    log_info "Downloading repaired reproducer files and repaired bugs with gdown"
    check_command gdown
    gdown "$REPAIRED_REPRODUCERS_GDRIVE_ID" || { log_error "Failed to download repaired reproducer files"; exit 1; }
    gdown "$REPAIRED_BUGS_GDRIVE_ID" || { log_error "Failed to download repaired bugs"; exit 1; }
    log_info "Repaired reproducer files downloaded."
}

extract_reproducers() {
    log_info "Extracting repaired reproducer files"
    check_command 7z
    7z x repaired_reproducers.7z || { log_error "Failed to extract repaired reproducer files"; exit 1; }
    sudo chown -R "$SUDO_USER":"$SUDO_USER" repaired_reproducers/
    7z x repaired_bugs.7z || { log_error "Failed to extract repaired bugs"; exit 1; }
    sudo chown -R "$SUDO_USER":"$SUDO_USER" repaired_bugs/
}

download_linux_next() {
    log_info "Downloading linux-next"
    check_command gdown
    gdown "$LINUX_NEXT_GDRIVE_ID" || { log_error "Failed to download linux-next kernel"; exit 1; }
}

extract_linux_next() {
    log_info "Extracting linux-next"
    check_command 7z
    7z x linux-next.7z || { log_error "Failed to extract linux-next kernel"; exit 1; }
    sudo chown -R "$SUDO_USER":"$SUDO_USER" linux-next/
}

check_if_user_in_kvm_group() {
    log_info "Checking if user is in kvm group"

    if id -nG "$SUDO_USER" | grep -qw "kvm"; then
        log_info "User $SUDO_USER is in kvm group."
    else
        log_error "User $SUDO_USER is not in kvm group. Adding the user to kvm group."
        sudo usermod -aG kvm "$SUDO_USER"
    fi
}

###############################################################################
# MAIN
###############################################################################
run_docker_container
# enable_venv
# check_if_user_in_kvm_group
# install_gdown
# download_linux_next
# download_reproducers
# extract_linux_next
# extract_reproducers

log_info "Setup completed successfully."

