FROM ubuntu:22.04

# 1) Set APT configuration and install needed packages
#    Combine into a single RUN instruction to reduce layers
RUN echo 'APT::Install-Suggests "0";' >> /etc/apt/apt.conf.d/00-docker && \
    echo 'APT::Install-Recommends "0";' >> /etc/apt/apt.conf.d/00-docker && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      python3 python3-pip python3-dev gcc build-essential pipx \
      jq bc flex bison libssl-dev libelf-dev git wget \
      libz3-java libjson-java sat4j unzip xz-utils lftp \
      p7zip-full vim time qemu-system openssh-client rsync && \
    rm -rf /var/lib/apt/lists/*

# 2) Create a non-root user
RUN useradd -ms /bin/bash apprunner

# 3) Download and install Go (example: removing tarball afterwards)
RUN wget -O /tmp/go.tar.gz https://go.dev/dl/go1.23.4.linux-amd64.tar.gz && \
    rm -rf /usr/local/go && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm /tmp/go.tar.gz

# Update PATH for Go
ENV PATH="/usr/local/go/bin:$PATH"

# 4) Switch to non-root user
USER apprunner
WORKDIR /home/apprunner

# 5) Install superc script
RUN wget -O - https://raw.githubusercontent.com/appleseedlab/superc/master/scripts/install.sh | bash

# 6) Configure environment variables
ENV COMPILER_INSTALL_PATH="/home/apprunner/0day"
ENV CLASSPATH="/usr/share/java/org.sat4j.core.jar:/usr/share/java/json-lib.jar:/home/apprunner/.local/share/superc/z3-4.8.12-x64-glibc-2.31/bin/com.microsoft.z3.jar:/home/apprunner/.local/share/superc/JavaBDD/javabdd-1.0b2.jar:/home/apprunner/.local/share/superc/xtc.jar:/home/apprunner/.local/share/superc/superc.jar:$CLASSPATH"
ENV PATH="/home/apprunner/.local/bin:$PATH"

# 7) Install kmax via pipx; update PATH for kmax
RUN pipx install kmax==4.5.2
ENV PATH="/home/apprunner/.local/pipx/venvs/kmax/bin:$PATH"

# 8) Copy your project into the container
ENV ICSE25_PATH="/home/apprunner/icse25"
COPY . "${ICSE25_PATH}"

# 9) Switch to root to adjust ownership
USER root
RUN chown -R apprunner:apprunner "${ICSE25_PATH}"

# 10) Return to non-root user
USER apprunner

# 11) Upgrade pip and install your Python dependencies
RUN python3 -m pip install --upgrade pip
RUN python3 -m pip install -r "${ICSE25_PATH}/requirements.txt"

# 12) Download files from google drive
# RUN gdown 17CqozrdX3Iehx9hmZdgGBD7i0KMGueKZ -O "${ICSE25_PATH}/debian_image.7z" && \
#     gdown 1Y2dr6nbXxzS_6y-iDUWKCkUH9iucwhv3 -O "${ICSE25_PATH}/linux_next.7z" && \
#     7z x "${ICSE25_PATH}/debian_image.7z -o${ICSE25_PATH}" && 7z x "${ICSE25_PATH}/linux_next.7z -o${ICSE25_PATH}" \
