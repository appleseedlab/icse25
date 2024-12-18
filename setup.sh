# install kmax
# kmax dependencies
sudo apt install -y pipx git-lfs python3-dev python3-pip gcc build-essential
# linux dependencies
sudo apt install -y flex bison bc libssl-dev libelf-dev git
# superc dependencies
sudo apt install -y wget libz3-java libjson-java sat4j unzip xz-utils lftp

# install superc and make.cross
wget -O - https://raw.githubusercontent.com/appleseedlab/superc/master/scripts/install.sh | bash

export COMPILER_INSTALL_PATH=$HOME/0day
export CLASSPATH=/usr/share/java/org.sat4j.core.jar:/usr/share/java/json-lib.jar:${HOME}/.local/share/superc/z3-4.8.12-x64-glibc-2.31/bin/com.microsoft.z3.jar:${HOME}/.local/share/superc/JavaBDD/javabdd-1.0b2.jar:${HOME}/.local/share/superc/xtc.jar:${HOME}/.local/share/superc/superc.jar:${CLASSPATH}
export PATH=${HOME}/.local/bin/:${PATH}

pipx install kmax

# install go
wget https://go.dev/dl/go1.23.4.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.23.4.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin

sudo apt install make libncurses-dev

# install qemu
sudo apt install qemu-system-x86

# install syzkaller
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath "$SCRIPT_DIR/..")"

SYZKALLER_SRC="$REPO_ROOT/syzkaller"
(cd $SYZKALLER_SRC; git submodule update --init --recursive; make;)

# create a debian image
export IMAGE=./debian_image
sudo apt install debootstrap
mkdir -p $REPO_ROOT$IMAGE
(cd $IMAGE; wget https://raw.githubusercontent.com/google/syzkaller/master/tools/create-image.sh -O create-image.sh)
(cd $IMAGE; chmod +x create-image.sh)
(cd $IMAGE; ./create-image.sh)

# install gdown
pip3 install gdown --break-system-packages

# download linux-next
gdown --id 1H_aNBlJZ9qBLF0gvOflBE3-rou0EEbmT
# download reproducer files with git-lfs
git-lfs pull
