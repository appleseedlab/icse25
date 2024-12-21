#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

# install go
echo "[+] Installing Go"

GOTAR=go1.23.4.linux-amd64.tar.gz
wget https://go.dev/dl/go1.23.4.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf $GOTAR
export PATH=$PATH:/usr/local/go/bin
echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.bashrc
source ~/.bashrc

# check if go is installed
if ! command -v go &> /dev/null
then
    echo "  [-] go could not be found"
    exit
else
    echo "  [+] go is installed"
    # remove the tar file
    rm $GOTAR
fi

echo "[+] Installing dependencies"
sudo apt update
sudo apt install -y build-essentials make libncurses-dev qemu-system-x86 debootstrap python3 python3-pip git-lfs git

# install syzkaller
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath "$SCRIPT_DIR/")"

SYZKALLER_SRC="$REPO_ROOT/syzkaller"

echo "[+] Installing syzkaller"
(cd $SYZKALLER_SRC; git submodule update --init --recursive; make;)

# create a debian image
export IMAGE=./debian_image
mkdir -p $REPO_ROOT/$IMAGE

echo "[+] Creating a debian image"
(cd $IMAGE; wget https://raw.githubusercontent.com/google/syzkaller/master/tools/create-image.sh -O create-image.sh)
(cd $IMAGE; chmod +x create-image.sh)
(cd $IMAGE; ./create-image.sh)

# install gdown
echo "[+] Installing gdown"
pip3 install gdown --break-system-packages

# download linux-next
echo "[+] Downloading linux-next"
gdown --id 1H_aNBlJZ9qBLF0gvOflBE3-rou0EEbmT

# download reproducer files with git-lfs
echo "[+] Downloading reproducer files"
git-lfs pull
