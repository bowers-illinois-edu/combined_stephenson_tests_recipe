#!/usr/bin/env bash
set -euo pipefail

# Builds two images from recipes/ubuntu/Dockerfile
# (memo_campus_cluster_2026-10-12.md, Sections 3.5 and 5):
#
#   jwbowers/jake_cluster  R and the paper's packages, no Gurobi; the image
#                          the Campus Cluster runs under Apptainer
#   jwbowers/jake_dev      the same plus editors, TeX Live, Neovim and Gurobi,
#                          for working in a container on the laptop
#
# Each image gets two tags, <VERSION> and <VERSION>-<first seven characters of
# the paper commit>.  A .sif built from the second tag therefore names the
# lockfile it carries, the way Felipe's image tags name the code they carry.
#
# The lockfile is not maintained in this repository.  It is copied from the
# paper repository as committed at PAPER_REF, so the image carries the
# packages the paper's analyses record, and renv.lock.SOURCE records which
# commit that was.  Commit both files after a build to keep the record.
#
# Environment variables, all optional:
#   PAPER_REPO       the paper repository (default ~/repos/combined_stephenson_tests)
#   PAPER_REF        the commit to take renv.lock from (default HEAD)
#   R_DEB_VERSION    the Debian build of R from CRAN's Ubuntu noble repository
#                    (default 4.6.1-6.2404.0); it must be a build of the R
#                    version the lock records, and the builds available are
#                    listed in https://cloud.r-project.org/bin/linux/ubuntu/noble-cran40/Packages
#   TARGETS          the images to build: "cluster dev" (default), "cluster" or "dev"
#   DOCKER_PLATFORM  default linux/amd64, because the cluster's nodes are
#                    x86-64 and Gurobi's linux64 build is x86-64 only
#   KEEP_GUROBI      1 (default) puts Gurobi in the dev image; 0 leaves it out
#   PREPARE_ONLY     1 copies the lockfile and checks the R version, then
#                    stops before building, to inspect the lockfile's diff
#   GITHUB_PAT       not needed as of 2026-10-12: the lock's GitHub packages
#                    (CMRSS, QIoT, RIQITE) are public.  A token passed as a
#                    build argument can be read back with `docker history`.

# Run from recipes/, which is the build context, so that renv.lock and the
# scripts are inside it.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VERSION=0.3
PAPER_REPO="${PAPER_REPO:-$HOME/repos/combined_stephenson_tests}"
PAPER_REF="${PAPER_REF:-HEAD}"
R_DEB_VERSION="${R_DEB_VERSION:-4.6.1-6.2404.0}"
TARGETS="${TARGETS:-cluster dev}"
DOCKER_PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"
KEEP_GUROBI="${KEEP_GUROBI:-1}"
D_USERNAME="${USER:-$(id -un)}"

# Copy the lockfile as committed, not as it sits in the paper repository's
# working tree, so that the commit recorded in renv.lock.SOURCE is the
# lockfile actually used.
PAPER_SHA="$(git -C "$PAPER_REPO" rev-parse --verify "$PAPER_REF^{commit}")"
git -C "$PAPER_REPO" show "$PAPER_SHA:renv.lock" > renv.lock
printf 'Copied from %s at commit %s on %s\n' \
  "$PAPER_REPO" "$PAPER_SHA" "$(date +%F)" > renv.lock.SOURCE
echo "renv.lock: paper repository at ${PAPER_SHA:0:7} ($(git -C "$PAPER_REPO" log -1 --format=%s "$PAPER_SHA"))"

# The Debian build of R must be a build of the R the lock records.  The
# Dockerfile checks the installed R again, but failing here saves the time
# the build would spend before reaching that check.
R_VERSION="$(python3 -I -c 'import json, sys; print(json.load(open(sys.argv[1]))["R"]["Version"])' renv.lock)"
case "$R_DEB_VERSION" in
  "$R_VERSION"-*) ;;
  *)
    echo "R_DEB_VERSION=$R_DEB_VERSION is not a build of R $R_VERSION, which the lock records." >&2
    echo "Set R_DEB_VERSION to a $R_VERSION build listed in" >&2
    echo "  https://cloud.r-project.org/bin/linux/ubuntu/noble-cran40/Packages" >&2
    exit 1
    ;;
esac
echo "R: $R_VERSION, Debian build $R_DEB_VERSION"

if [[ "${PREPARE_ONLY:-0}" == "1" ]]; then
  echo "PREPARE_ONLY=1: lockfile copied, nothing built. See: git diff -- recipes/renv.lock"
  exit 0
fi

TAG_SHA="${VERSION}-${PAPER_SHA:0:7}"
for target in $TARGETS; do
  case "$target" in
    cluster) image=jwbowers/jake_cluster ;;
    dev)     image=jwbowers/jake_dev ;;
    *) echo "unknown target '$target': use cluster or dev" >&2; exit 1 ;;
  esac

  DOCKER_ARGS=(
    -f ubuntu/Dockerfile
    --target "$target"
    --platform "$DOCKER_PLATFORM"
    -t "$image:$VERSION"
    -t "$image:$TAG_SHA"
    --build-arg "D_USERNAME=$D_USERNAME"
    --build-arg "R_VERSION=$R_VERSION"
    --build-arg "R_DEB_VERSION=$R_DEB_VERSION"
    --build-arg "KEEP_GUROBI=$KEEP_GUROBI"
    --build-arg "PAPER_COMMIT=$PAPER_SHA"
    --rm=true
  )
  if [[ -n "${GITHUB_PAT:-}" ]]; then
    DOCKER_ARGS+=(--build-arg "GITHUB_PAT=${GITHUB_PAT}")
  fi

  echo "building $image:$TAG_SHA (target $target, platform $DOCKER_PLATFORM)"
  docker build "${DOCKER_ARGS[@]}" .
done

echo
echo "Commit the lockfile record:"
echo "  git add recipes/renv.lock recipes/renv.lock.SOURCE"
echo "Push:"
for target in $TARGETS; do
  case "$target" in cluster) image=jwbowers/jake_cluster ;; dev) image=jwbowers/jake_dev ;; esac
  echo "  docker push $image:$VERSION && docker push $image:$TAG_SHA"
done
echo "On the Campus Cluster, inside an interactive job (login nodes stop processes after 30 CPU-minutes):"
echo "  export APPTAINER_CACHEDIR=/projects/illinois/las/pol/jwbowers/apptainer_cache"
echo "  apptainer build jake_cluster-$TAG_SHA.sif docker://jwbowers/jake_cluster:$TAG_SHA"
