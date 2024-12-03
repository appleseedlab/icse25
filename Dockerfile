FROM ubuntu:22.04
RUN echo 'APT::Install-Suggests "0";' >> /etc/apt/apt.conf.d/00-docker
RUN echo 'APT::Install-Recommends "0";' >> /etc/apt/apt.conf.d/00-docker
RUN DEBIAN_FRONTEND=noninteractive \
  apt-get update \
  && apt-get install -y python3 python3-pip pipx python3-dev gcc build-essential \
  && apt-get install -y jq bc flex bison bc libssl-dev libelf-dev git \
  && apt-get install -y wget libz3-java libjson-java sat4j unzip xz-utils lftp \
  && rm -rf /var/lib/apt/lists/*
RUN pip3 install gdown
RUN useradd -ms /bin/bash apprunner

# install go
RUN wget https://go.dev/dl/go1.23.3.src.tar.gz -O /home/apprunner/go1.23.3.src.tar.gz
RUN rm -rf /usr/local/go && tar -C /usr/local -xzf /home/apprunner/go1.23.3.src.tar.gz
ENV PATH=$PATH:/usr/local/go/bin

USER apprunner
WORKDIR /home/apprunner
RUN wget -O - https://raw.githubusercontent.com/appleseedlab/superc/master/scripts/install.sh | bash
ENV COMPILER_INSTALL_PATH=/home/apprunner/0day
ENV CLASSPATH=/usr/share/java/org.sat4j.core.jar:/usr/share/java/json-lib.jar:/home/apprunner/.local/share/superc/z3-4.8.12-x64-glibc-2.31/bin/com.microsoft.z3.jar:/home/apprunner/.local/share/superc/JavaBDD/javabdd-1.0b2.jar:/home/apprunner/.local/share/superc/xtc.jar:/home/apprunner/.local/share/superc/superc.jar:${CLASSPATH}
ENV PATH=/home/apprunner/.local/bin/:${PATH}
RUN pipx install kmax
ENV PATH=/home/apprunner/.local/pipx/venvs/kmax/bin/:${PATH}
RUN gdown --id 1H_aNBlJZ9qBLF0gvOflBE3-rou0EEbmT
RUN 7z x linux-next.7z -o /home/apprunner

ENV ICSE25_PATH=/home/apprunner/icse25
# ADD . ${ICSE25_PATH}
RUN echo "alias change_study='bash ${ICSE25_PATH}/krepair_syzkaller_evaluation/change_summary_2.sh ${ICSE25_PATH}/change_study.csv'" >> /home/apprunner/.bashrc
