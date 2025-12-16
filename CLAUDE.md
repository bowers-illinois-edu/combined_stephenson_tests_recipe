# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains Docker/Singularity image recipes for running simulations and analyses for the "combined Stephenson tests" paper. It builds an Ubuntu-based container with R and required packages managed via renv.

## Build Commands

Build the Docker image (from repo root):
```bash
DOCKER_PLATFORM=linux/amd64 KEEP_GUROBI=1 bash recipes/build_ubuntu.sh
```

Environment variables for build:
- `DOCKER_PLATFORM` - Set to `linux/amd64` for x86_64 architecture
- `KEEP_GUROBI=1` - Include Gurobi optimizer package (requires x86_64)
- `GITHUB_PAT` - GitHub personal access token for private package installs

Push to registry:
```bash
docker push jwbowers/jake_dev:0.1
```

Convert to Singularity:
```bash
./docker2singularity jwbowers/jake_dev:0.1
```

## Architecture

- `recipes/ubuntu/Dockerfile` - Main container definition (Ubuntu 24.04 + R 4.5.2)
- `recipes/build_ubuntu.sh` - Build script that sets up Docker build arguments
- `recipes/renv.lock` - R package dependencies managed by renv
- `recipes/renv/cellar/` - Local R package tarballs (e.g., Gurobi)
- `recipes/scripts/renv_filter_lock.py` - Filters lockfile based on architecture/build options
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
