#!/usr/bin/env bash
set -euo pipefail

# Always run from the recipes/ directory so the build context (.) includes recipes/renv.lock
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

export DISTRO=ubuntu
export IMAGE=jake_dev
export TAG=0.1
export D_USERNAME="${USER:-$(id -un)}"

# If you need to restore private GitHub packages during renv::restore(), set GITHUB_PAT in your env.
DOCKER_ARGS=(
  -f "$DISTRO/Dockerfile"
  -t "jwbowers/$IMAGE:$TAG"
  --build-arg "D_USERNAME=$D_USERNAME"
  --rm=true
)

if [[ -n "${DOCKER_PLATFORM:-}" ]]; then
  DOCKER_ARGS+=(--platform "$DOCKER_PLATFORM")
fi

if [[ -n "${GITHUB_PAT:-}" ]]; then
  DOCKER_ARGS+=(--build-arg "GITHUB_PAT=${GITHUB_PAT}")
fi

if [[ -n "${KEEP_GUROBI:-}" ]]; then
  DOCKER_ARGS+=(--build-arg "KEEP_GUROBI=${KEEP_GUROBI}")
fi

docker build "${DOCKER_ARGS[@]}" .

echo 'Push commands:'
echo "   docker push jwbowers/$IMAGE:${TAG}"

echo 'To create singularity image:'
echo "  ./docker2singularity jwbowers/$IMAGE:${TAG}"
