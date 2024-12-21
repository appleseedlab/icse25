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
install_go() {
    log_info "Installing Go ${GOVER}"
    check_command wget
    wget -q "$GOURL" -O "$GOTAR" || { log_error "Failed to download Go tarball"; exit 1; }

    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "$GOTAR"
    rm "$GOTAR"

    # Update PATH for the current session
    export PATH=$PATH:/usr/local/go/bin

    # Ensure Go is available in future shells
    if ! grep -q "/usr/local/go/bin" ~/.bashrc; then
        echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.bashrc
    fi

    check_command go
    log_info "Go ${GOVER} installed."

}

install_dependencies() {
    log_info "Installing system dependencies"
    check_command apt
    sudo apt-get update -y
    sudo apt-get install -y build-essential make libncurses-dev qemu-system-x86 debootstrap python3 python3-pip git-lfs git wget curl p7zip-full flex bison bc libelf-dev libssl-dev
}

install_gdown() {
    log_info "Ensuring gdown is installed"
    if ! command -v gdown &>/dev/null; then
        # Install gdown without affecting system packages too heavily
        python3 -m pip install gdown --break-system-packages
        # Refresh shell hash
        hash -r
        if ! command -v gdown &>/dev/null; then
            log_error "gdown installation failed."
            exit 1
        fi
    fi
    log_info "gdown is installed."
}

install_syzkaller() {
    log_info "Installing syzkaller"
    check_command git
    if [ ! -d "$SYZKALLER_SRC" ]; then
        log_error "Syzkaller source directory not found at $SYZKALLER_SRC."
        exit 1
    fi
    (cd "$SYZKALLER_SRC"; git submodule update --init --recursive; make)
    log_info "Syzkaller installation complete."
}

install_docker() {
    log_info "Installing Docker"

    # Detect distro
    source /etc/os-release
    if [[ "$ID" == "ubuntu" ]]; then
        REPO_URL="https://download.docker.com/linux/ubuntu"
    elif [[ "$ID" == "debian" && "$VERSION_CODENAME" == "bookworm" ]]; then
        REPO_URL="https://download.docker.com/linux/debian"
    else
        echo "This script currently only supports Ubuntu and Debian 12 (bookworm)."
        return 1
    fi

    # Update packages, install prerequisites
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl

    # Setup Docker GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL "${REPO_URL}/gpg" -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add Docker repo
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] $REPO_URL \
      $VERSION_CODENAME stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Final install
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    check_command docker
    log_info "Docker is installed."
}

create_debian_image() {
    log_info "Creating a Debian image"
    mkdir -p "$IMAGE_DIR"
    (cd "$IMAGE_DIR"; wget -q "$DEBIAN_IMAGE_URL" -O create-image.sh)
    chmod +x "$IMAGE_DIR/create-image.sh"

    # Consider checking if create-image.sh was downloaded successfully
    if [ ! -f "$IMAGE_DIR/create-image.sh" ]; then
        log_error "Failed to download create-image.sh"
        exit 1
    fi

    (cd "$IMAGE_DIR"; ./create-image.sh)
    log_info "Debian image creation complete."
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

download_reproducers() {
    log_info "Downloading reproducer files with git-lfs"
    check_command git-lfs
    # Ensure the repository and .gitattributes are set up
    git-lfs pull
    log_info "Reproducer files downloaded."
}

###############################################################################
# MAIN
###############################################################################
install_go
install_dependencies
install_docker
install_gdown
install_syzkaller
create_debian_image
download_linux_next
download_reproducers
extract_linux_next

log_info "Setup completed successfully."

