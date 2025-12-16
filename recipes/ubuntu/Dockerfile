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
RUN apt-get install -y wget emacs git vim neovim curl eza tmux htop pandoc curl gdebi-core ripgrep

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
        pkg-config \
        libcurl4-openssl-dev libssl-dev libxml2-dev \
        libgit2-dev \
        libfontconfig1-dev libharfbuzz-dev libfribidi-dev \
        libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev \
      && rm -rf /var/lib/apt/lists/* ; \
    fi

# 4) Set default CRAN mirror (so install.packages() works non-interactively)
RUN printf '%s\n' \
    'local({' \
    '  r <- getOption("repos");' \
    '  r["CRAN"] <- "https://cloud.r-project.org";' \
    '  options(repos = r)' \
    '})' \
    > /etc/R/Rprofile.site

# 5) Restore R packages from renv.lock (CRAN + GitHub), installing into the global site library
# IMPORTANT: Build with the repo root as context so renv.lock is available, e.g.:
#   docker build -f recipes/ubuntu/Dockerfile -t spt3g_ubuntu --build-arg D_USERNAME=jake .
WORKDIR /opt/recipe
COPY renv.lock /opt/recipe/renv.lock

# Optional: include local renv cellar tarballs in the build context (e.g., Gurobi).
COPY renv/cellar/ /opt/recipe/renv/cellar/
COPY scripts/renv_filter_lock.py /opt/recipe/renv_filter_lock.py

# Put renv cache somewhere stable to improve layer reuse
ENV RENV_PATHS_CACHE=/opt/renv/cache
ENV RENV_PATHS_CELLAR=/opt/recipe/renv/cellar

# Optional: enable private GitHub installs at build time
ARG GITHUB_PAT
ARG KEEP_GUROBI=1

RUN R -e 'install.packages("renv", repos = "https://cloud.r-project.org")' \
 && mkdir -p /usr/local/lib/R/site-library \
 && RENV_KEEP_GUROBI="$KEEP_GUROBI" python3 /opt/recipe/renv_filter_lock.py /opt/recipe/renv.lock /opt/recipe/renv.docker.lock \
 && if [ -n "$GITHUB_PAT" ]; then export GITHUB_PAT="$GITHUB_PAT"; fi \
 && R -e 'renv::restore(lockfile = "/opt/recipe/renv.docker.lock", library = "/usr/local/lib/R/site-library", prompt = FALSE)' \
 && if [ "$KEEP_GUROBI" = "1" ] && [ -f /opt/recipe/renv/cellar/gurobi/gurobi_12.0-3.tar.gz ]; then \
      ARCH=$(uname -m); \
      if [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "amd64" ]; then \
        R -e 'install.packages("/opt/recipe/renv/cellar/gurobi/gurobi_12.0-3.tar.gz", repos = NULL, lib = "/usr/local/lib/R/site-library")'; \
      else \
        echo "Skipping gurobi install on architecture $ARCH (requires x86_64/amd64)"; \
      fi; \
    fi

ARG D_USERNAME
RUN useradd -ms /bin/bash $D_USERNAME && \
    addgroup wheel

ENV USER=$D_USERNAME
ENV HOME=/home/$D_USERNAME
ENV SHELL=/bin/bash

USER $D_USERNAME
WORKDIR /home/$D_USERNAME
