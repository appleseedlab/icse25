#!/usr/bin/env bash
set -euo pipefail

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
run_docker_container(){
    containername="icse25-artifacts"
    image_home="/home/apprunner"

    docker build -t $containername .

    docker ps -aq --filter "name=$containername" | grep -q . && \
        docker stop $containername && docker rm $containername

    docker run -it \
    --device=/dev/kvm \
    -v $(pwd)/kernel_images:$image_home/icse25/kernel_images \
    -v $(pwd)/linux-next:$image_home/icse25/linux-next \
    -v $(pwd)/debian_image:$image_home/icse25/debian_image \
    $containername  /bin/bash
}
change_kvm_permissions() {
    log_info "Changing permissions for /dev/kvm to allow non-root users to access KVM"

    # Check if /dev/kvm exists
    if [ ! -e /dev/kvm ]; then
        log_error "/dev/kvm does not exist. Exiting."
        exit 1
    fi

    sudo chmod 666 /dev/kvm || { log_error "Failed to change permissions for /dev/kvm"; exit 1; }

    log_info "Permissions for /dev/kvm changed successfully."
}

###############################################################################
# MAIN
###############################################################################
change_kvm_permissions
run_docker_container

