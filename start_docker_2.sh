#!/usr/bin/env bash
set -euo pipefail

# Local testing helper for Docker Desktop (macOS).
#
# If you see: "no matching manifest for linux/amd64", it usually means you
# haven't built the image locally for amd64 yet (or the registry tag doesn't
# contain an amd64 variant). Build first with:
#   DOCKER_PLATFORM=linux/amd64 KEEP_GUROBI=1 bash recipes/build_ubuntu.sh

D_USERNAME="${D_USERNAME:-${USER}}"
IMAGE="${IMAGE:-jwbowers/jake_dev}"
TAG="${TAG:-0.3}"
PLATFORM="${PLATFORM:-linux/amd64}"
NVIM_CONFIG_DIR="${NVIM_CONFIG_DIR:-$HOME/.config/nvim}"

docker run --pull=never --rm -it --platform "$PLATFORM" \
  -v "$NVIM_CONFIG_DIR:/home/$D_USERNAME/.config/nvim:ro" \
  -v "$HOME/.gurobi:/home/$D_USERNAME/.gurobi:ro" \
  -e "GRB_LICENSE_FILE=/home/$D_USERNAME/.gurobi/gurobi.lic" \
  "$IMAGE:$TAG" bash -lc 'mkdir -p "$HOME/.local/state" "$HOME/.local/share" "$HOME/.cache" && exec bash'
