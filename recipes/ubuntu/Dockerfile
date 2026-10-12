# Two images from one file (memo_campus_cluster_2026-10-12.md, Sections 3.5
# and 5):
#
#   cluster  R at the version the paper repository's renv.lock records and
#            every package in that lock except gurobi.  Cluster runs use
#            HiGHS, which needs no licence.  Run under Apptainer on the
#            Campus Cluster.
#   dev      the cluster image plus editors, TeX Live, Node, Neovim and
#            Gurobi, for working in a container on the laptop.
#
# dev is built on top of cluster, so both carry the same R and the same
# package library, layer for layer.  dev is the last stage, so a plain
# `docker build` still produces it; `--target cluster` produces the other.
# recipes/build_ubuntu.sh builds both, after copying renv.lock in from the
# paper repository.  Build with recipes/ as the context.

########################################################################
FROM ubuntu:24.04 AS cluster
ARG DEBIAN_FRONTEND=noninteractive

# 1) System libraries.  The compilers arrive with r-base-dev below.  These are
# the libraries the packages in renv.lock compile against, read from the
# lock's SystemRequirements fields: cmake for highs, libuv for fs, libwebp for
# ragg, the font stack for systemfonts and textshaping, libxml2 for xml2, and
# tzdata for lubridate and timechange.  python3 runs renv_filter_lock.py.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl wget gpg git python3 tzdata \
      build-essential pkg-config cmake \
      libcurl4-openssl-dev libssl-dev libxml2-dev libgit2-dev libuv1-dev \
      libfontconfig1-dev libharfbuzz-dev libfribidi-dev libfreetype6-dev \
      libpng-dev libtiff5-dev libjpeg-dev libwebp-dev \
 && rm -rf /var/lib/apt/lists/*

# 2) R, pinned to one Debian build.  CRAN's Ubuntu repository keeps earlier
# builds, so the exact version can be named; without the pin the image would
# get whatever R CRAN serves on the day of the build.  build_ubuntu.sh reads
# R_VERSION from the lockfile and checks that R_DEB_VERSION is a build of it;
# the test at the end of this step stops the build if the installed R differs.
ARG R_VERSION=4.6.1
ARG R_DEB_VERSION=4.6.1-6.2404.0
RUN mkdir -p /usr/share/keyrings \
 && wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc \
      | gpg --dearmor -o /usr/share/keyrings/cran.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/cran.gpg] https://cloud.r-project.org/bin/linux/ubuntu noble-cran40/" \
      > /etc/apt/sources.list.d/cran.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      r-base-core="$R_DEB_VERSION" \
      r-base-dev="$R_DEB_VERSION" \
      r-recommended="$R_DEB_VERSION" \
 && rm -rf /var/lib/apt/lists/* \
 && test "$(Rscript -e 'cat(as.character(getRversion()))')" = "$R_VERSION"

# 3) Default CRAN mirror, so install.packages() works non-interactively.
RUN printf '%s\n' \
    'local({' \
    '  r <- getOption("repos");' \
    '  r["CRAN"] <- "https://cloud.r-project.org";' \
    '  options(repos = r)' \
    '})' \
    > /etc/R/Rprofile.site

# 4) The packages in the paper repository's renv.lock, which build_ubuntu.sh
# copies here beside renv.lock.SOURCE (the commit it came from).  gurobi is
# dropped from the lock for this stage, because its R package needs the
# Gurobi library, which only the dev stage installs.  The library is the
# site library, which every R process in the container searches first.
WORKDIR /opt/recipe
COPY renv.lock renv.lock.SOURCE /opt/recipe/
COPY scripts/renv_filter_lock.py scripts/check_image.R /opt/recipe/
ENV RENV_PATHS_CACHE=/opt/renv/cache
# Not needed for the lock as of 2026-10-12: its GitHub packages are public.
ARG GITHUB_PAT
RUN R -e 'install.packages("renv", repos = "https://cloud.r-project.org")' \
 && RENV_KEEP_GUROBI=0 python3 /opt/recipe/renv_filter_lock.py \
      /opt/recipe/renv.lock /opt/recipe/renv.docker.lock \
 && R -e 'renv::restore(lockfile = "/opt/recipe/renv.docker.lock", library = "/usr/local/lib/R/site-library", prompt = FALSE)'

# 5) Inside the container the paper repository's .Rprofile would start renv,
# which would look for a project library built for this platform, find none,
# and offer to restore one.  The packages are in the site library instead,
# so renv stays off.  renv/activate.R reads this variable.
ENV RENV_CONFIG_AUTOLOADER_ENABLED=FALSE

# 6) The image must match the lock, or the build stops here.  The BLAS R
# uses is recorded so that the dev stage can confirm it did not change it.
RUN Rscript /opt/recipe/check_image.R cluster /opt/recipe/renv.lock \
 && Rscript -e 'cat(sessionInfo()$BLAS)' > /opt/recipe/blas.cluster

# 7) The account.  Under Apptainer the container runs as whoever starts it
# and this account is unused; Docker on the laptop uses it.
ARG D_USERNAME
RUN useradd -ms /bin/bash "$D_USERNAME" \
 && addgroup wheel \
 && mkdir -p \
      /home/$D_USERNAME/.config \
      /home/$D_USERNAME/.local/share \
      /home/$D_USERNAME/.local/state \
      /home/$D_USERNAME/.cache \
 && chown $D_USERNAME:$D_USERNAME /home/$D_USERNAME \
 && chown -R $D_USERNAME:$D_USERNAME \
      /home/$D_USERNAME/.config \
      /home/$D_USERNAME/.local \
      /home/$D_USERNAME/.cache

ARG PAPER_COMMIT=unknown
LABEL paper.renv_lock.commit="$PAPER_COMMIT"
ENV USER=$D_USERNAME
ENV HOME=/home/$D_USERNAME
ENV SHELL=/bin/bash

USER $D_USERNAME
WORKDIR /home/$D_USERNAME

########################################################################
FROM cluster AS dev
USER root
ARG DEBIAN_FRONTEND=noninteractive
ARG NEOVIM_MIN_VERSION=0.11.0
ARG NEOVIM_VERSION=0.11.0

# 8) Editors, TeX Live, Node and the AstroNvim prerequisites.
# software-properties-common and the python3 packages serve
# add-apt-repository in the Neovim step.
RUN apt-get update --fix-missing \
 && apt-get install -y \
      wget emacs git vim curl eza tmux htop pandoc gdebi-core ripgrep \
      nodejs npm \
      python3-pip python3-venv \
      lua5.1 luarocks \
      fd-find fzf unzip \
      xclip xsel \
      texlive-latex-extra texlive-xetex latexmk biber \
      bat \
      software-properties-common python3-dbus python3-gi python3-apt \
 && rm -rf /var/lib/apt/lists/*

RUN if command -v fdfind >/dev/null && ! command -v fd >/dev/null; then ln -s /usr/bin/fdfind /usr/local/bin/fd; fi \
 && if command -v batcat >/dev/null && ! command -v bat >/dev/null; then ln -s /usr/bin/batcat /usr/local/bin/bat; fi

# 9) Neovim at NEOVIM_MIN_VERSION or newer: the stable PPA, then the unstable
# one, then the release tarball.  Neovim renamed its x86-64 tarball from
# nvim-linux64 to nvim-linux-x86_64 in version 0.10.4.
RUN set -eu; \
    try_ppa() { \
      ppa="$1"; \
      add-apt-repository -y "$ppa" >/dev/null; \
      apt-get update >/dev/null; \
      candidate="$(apt-cache policy neovim | awk -F': ' '/Candidate:/ {print $2}')"; \
      if [ "$candidate" != "(none)" ] && dpkg --compare-versions "$candidate" ge "$NEOVIM_MIN_VERSION"; then \
        apt-get install -y --no-install-recommends neovim >/dev/null; \
        return 0; \
      fi; \
      return 1; \
    }; \
    if ! try_ppa ppa:neovim-ppa/stable && ! try_ppa ppa:neovim-ppa/unstable; then \
      echo "No PPA candidate >= $NEOVIM_MIN_VERSION for this distro; installing Neovim v$NEOVIM_VERSION from GitHub releases." >&2; \
      arch="$(dpkg --print-architecture)"; \
      case "$arch" in \
        amd64) nvim_pkg="nvim-linux-x86_64" ;; \
        arm64) nvim_pkg="nvim-linux-arm64" ;; \
        *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
      esac; \
      curl -fsSL --retry 3 -o /tmp/nvim.tar.gz \
        "https://github.com/neovim/neovim/releases/download/v${NEOVIM_VERSION}/${nvim_pkg}.tar.gz"; \
      mkdir -p /opt; \
      tar -C /opt -xzf /tmp/nvim.tar.gz; \
      rm /tmp/nvim.tar.gz; \
      ln -sf "/opt/${nvim_pkg}/bin/nvim" /usr/local/bin/nvim; \
    fi; \
    nvim_line="$(nvim --version | head -n 1)"; \
    echo "$nvim_line"; \
    nvim_ver="$(printf '%s' "$nvim_line" | awk '{print $2}' | sed 's/^v//')"; \
    dpkg --compare-versions "$nvim_ver" ge "$NEOVIM_MIN_VERSION"; \
    rm -rf /var/lib/apt/lists/*

# 10) Gurobi, for the laptop.  Its R interface ships inside Gurobi's own
# distribution, one build per R minor version, so it is installed from there
# and not through renv (the lock records it as "Cellar").  The download is
# checked against the SHA-256 computed on 2026-10-12.  No licence is
# installed, and a machine-tied academic licence does not work in a
# container; Gurobi here needs a WLS licence (memo, Section 9).  The dev
# check then requires every package in the lock, gurobi included.
ARG KEEP_GUROBI=1
ARG R_VERSION=4.6.1
ARG GUROBI_VERSION=13.0.3
ARG GUROBI_DIR=gurobi1303
ARG GUROBI_SHA256=2e16903535a2db67c1be14f075dfa532cf1d4d5961d742d1f9894156d8f4c6f1
RUN if [ "$KEEP_GUROBI" = "1" ]; then \
      set -eu; \
      curl -fsSL --retry 3 -o /tmp/gurobi.tar.gz \
        "https://packages.gurobi.com/${GUROBI_VERSION%.*}/gurobi${GUROBI_VERSION}_linux64.tar.gz"; \
      echo "$GUROBI_SHA256  /tmp/gurobi.tar.gz" | sha256sum -c -; \
      tar -C /opt -xzf /tmp/gurobi.tar.gz; \
      rm /tmp/gurobi.tar.gz; \
      echo "/opt/$GUROBI_DIR/linux64/lib" > /etc/ld.so.conf.d/gurobi.conf; \
      ldconfig; \
      rpkg="$(ls /opt/$GUROBI_DIR/linux64/R/gurobi_*_R_${R_VERSION%.*}.*.tar.gz | head -n 1)"; \
      test -n "$rpkg"; \
      R -e "install.packages('$rpkg', repos = NULL, type = 'source', lib = '/usr/local/lib/R/site-library')"; \
      Rscript /opt/recipe/check_image.R dev /opt/recipe/renv.lock; \
    fi
ENV GUROBI_HOME=/opt/${GUROBI_DIR}/linux64
ENV PATH="${PATH}:${GUROBI_HOME}/bin"

# 11) The apt packages above must not have changed the BLAS R uses.  Some
# packages pull in OpenBLAS, which would then replace the reference BLAS for
# every program, and the dev image would no longer compute as the cluster
# image does.
RUN blas_now="$(Rscript -e 'cat(sessionInfo()$BLAS)')" \
 && if [ "$blas_now" != "$(cat /opt/recipe/blas.cluster)" ]; then \
      echo "The dev stage changed R's BLAS from $(cat /opt/recipe/blas.cluster) to $blas_now" >&2; \
      exit 1; \
    fi

ARG D_USERNAME
USER $D_USERNAME
WORKDIR /home/$D_USERNAME
