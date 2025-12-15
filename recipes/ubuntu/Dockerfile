# To build:
# docker build -t spt3g_ubuntu --build-arg SPTUSER --rm=true .

# To start:
# hostname="`hostname -s`-docker"
# DOCKER_IMA=spt3g_ubuntu:latest
# docker run -ti -h $hostname -v $HOME/SPT-3G/home-spt3g:/home/$SPTUSER $DOCKER_IMA bash

# Clean up:
# docker rm $(docker ps -a -q)

# Latest version
FROM ubuntu:24.04
ARG DEBIAN_FRONTEND=noninteractive
# Set to 1 to install common build deps; 0 for a lean image
ARG DEV=1

RUN apt-get update --fix-missing
RUN apt-get install -y wget emacs git vim neovim curl eza tmux htop pandoc curl gdebi-core

# 1) Basics + CRAN repo key and source (noble)
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates wget gpg apt-transport-https software-properties-common \
    && mkdir -p /usr/share/keyrings \
    && wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc \
         | gpg --dearmor -o /usr/share/keyrings/cran.gpg \
    && sh -c 'echo "deb [signed-by=/usr/share/keyrings/cran.gpg] https://cloud.r-project.org/bin/linux/ubuntu noble-cran40/" > /etc/apt/sources.list.d/cran.list' \
    && apt-get update \
    && apt-get install -y r-base r-base-dev  \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      python3-dbus python3-gi python3-apt \
 && rm -rf /var/lib/apt/lists/*

# 2) (Optional) Common system libs for compiling R packages
RUN if [ "$DEV" = "1" ]; then \
      apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        libcurl4-openssl-dev libssl-dev libxml2-dev \
        libfontconfig1-dev libharfbuzz-dev libfribidi-dev \
        libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev \
      && rm -rf /var/lib/apt/lists/* ; \
    fi

# 3) Install quarto
ARG QUARTO_VERSION="1.8.25" # Or your desired version

RUN wget -O quarto-linux-amd64.deb https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb && \
    gdebi --non-interactive quarto-linux-amd64.deb && \
    rm quarto-linux-amd64.deb

# 4) Set default CRAN mirror (so install.packages() works non-interactively)
RUN printf '%s\n' \
    'local({' \
    '  r <- getOption("repos");' \
    '  r["CRAN"] <- "https://cloud.r-project.org";' \
    '  options(repos = r)' \
    '})' \
    > /etc/R/Rprofile.site

ARG D_USERNAME
RUN useradd -ms /bin/bash $D_USERNAME && \
    addgroup wheel

ENV USER=$D_USERNAME
ENV HOME=/home/$D_USERNAME
ENV SHELL=/bin/bash

USER $D_USERNAME
WORKDIR /home/$D_USERNAME
