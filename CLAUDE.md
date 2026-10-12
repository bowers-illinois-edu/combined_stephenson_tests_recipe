# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains Docker/Singularity image recipes for running simulations and analyses for the "combined Stephenson tests" paper. It builds two Ubuntu-based images, `jwbowers/jake_cluster` (for Apptainer on the Campus Cluster; no Gurobi, cluster runs use HiGHS) and `jwbowers/jake_dev` (adds editors, TeX Live, Neovim and Gurobi), with R and packages taken from the paper repository's renv.lock. `memo_campus_cluster_2026-10-12.md` records the plan and Jake's decisions.

## Build Commands

Build the Docker image (from repo root):
```bash
bash recipes/build_ubuntu.sh            # both images
TARGETS=cluster bash recipes/build_ubuntu.sh
PREPARE_ONLY=1 bash recipes/build_ubuntu.sh   # copy renv.lock from the paper repo, build nothing
```

Environment variables for build:
- `PAPER_REPO`, `PAPER_REF` - where renv.lock is copied from (default `~/repos/combined_stephenson_tests` at `HEAD`)
- `R_DEB_VERSION` - CRAN's Debian build of R (default `4.6.1-6.2404.0`); must match the lock's R version
- `DOCKER_PLATFORM` - default `linux/amd64`
- `KEEP_GUROBI=0` - leave Gurobi out of the dev image
- `GITHUB_PAT` - not needed; the lock's GitHub packages are public

Push to registry:
```bash
docker push jwbowers/jake_cluster:0.3
```

Convert to Singularity, on the Campus Cluster inside an interactive job:
```bash
export APPTAINER_CACHEDIR=/projects/illinois/las/pol/jwbowers/apptainer_cache
apptainer build jake_cluster-0.3.sif docker://jwbowers/jake_cluster:0.3
```

## Architecture

- `recipes/ubuntu/Dockerfile` - Two stages, `cluster` and `dev` (Ubuntu 24.04 + R pinned to the lock's version, 4.6.1)
- `recipes/build_ubuntu.sh` - Copies renv.lock from the paper repo, checks the R version, builds and tags both images
- `recipes/renv.lock`, `recipes/renv.lock.SOURCE` - Copy of the paper repo's lockfile and the commit it came from
- `recipes/scripts/check_image.R` - Run at the end of each build stage; fails the build unless R and every package match the lock
- `recipes/scripts/renv_filter_lock.py` - Drops gurobi from the lockfile before renv::restore()
- `home-jwbowers/` - Mounted as user home directory when running container
- `start_docker.sh` - Script to run the container interactively with X11 forwarding

## Running the Container

```bash
bash start_docker.sh
```

Re-enter running container:
```bash
docker exec -ti jake_dev bash
```

## Key R Packages

The container includes R packages for randomization inference including CMRSS (Combining Multiple Rank Sum Statistics) and RIQITE from GitHub, plus standard CRAN dependencies.
