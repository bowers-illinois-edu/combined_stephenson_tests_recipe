#!/usr/bin/env bash
set -euo pipefail

# Builds a cluster .sif from an existing one by installing, on top of it, the
# GitHub commit of CMRSS that recipes/renv.lock records, and then running
# check_image.R against that lockfile.
#
# Why this exists.  The proper way to change the image is build_ubuntu.sh,
# which needs Docker and a Docker Hub login.  On 2026-10-18 neither was
# available away from the laptop, and the Campus Cluster needed CMRSS 0.2.21
# to finish the regret study (task 89).  Jake chose to patch the old image
# on the cluster and to keep this recipe current so that the laptop can
# build the full image later.  The patched image differs from its base only
# in CMRSS, and check_image.R stops the build unless every package, CMRSS
# included, matches the lockfile.  Its tag carries a "p" (0.3p-<commit>) so
# that no one mistakes it for an image build_ubuntu.sh made.
#
# Run on the Campus Cluster inside an interactive job (login nodes stop
# processes after 30 CPU-minutes), from this directory:
#
#   BASE_TAG=0.3-5acbeaa bash build_patch.sh
#
# Environment variables:
#   BASE_TAG        the tag of the .sif to start from (required)
#   IMAGES          where the .sifs live
#                   (default /projects/illinois/las/pol/jwbowers/images)
#   BUILD_FLAGS     flags for apptainer build (default --fakeroot)

: "${BASE_TAG:?set BASE_TAG to the tag of the .sif to patch, e.g. 0.3-5acbeaa}"
IMAGES="${IMAGES:-/projects/illinois/las/pol/jwbowers/images}"
BUILD_FLAGS="${BUILD_FLAGS:---fakeroot}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECIPES="$(dirname "$SCRIPT_DIR")"
cd "$SCRIPT_DIR"

BASE_SIF="$IMAGES/jake_cluster-${BASE_TAG}.sif"
[[ -f "$BASE_SIF" ]] || { echo "no base image at $BASE_SIF" >&2; exit 1; }

# The paper commit the lockfile came from, as build_ubuntu.sh recorded it,
# and the CMRSS commit the lockfile names.
PAPER_SHA="$(sed -n 's/.* at commit \([0-9a-f]\{40\}\) on .*/\1/p' "$RECIPES/renv.lock.SOURCE")"
CMRSS_SHA="$(python3 -I -c 'import json, sys; print(json.load(open(sys.argv[1]))["Packages"]["CMRSS"]["RemoteSha"])' "$RECIPES/renv.lock")"
[[ -n "$PAPER_SHA" && -n "$CMRSS_SHA" ]] || { echo "could not read the commits from renv.lock.SOURCE and renv.lock" >&2; exit 1; }

TAG="${BASE_TAG%%-*}p-${PAPER_SHA:0:7}"
OUT="$IMAGES/jake_cluster-${TAG}.sif"
[[ ! -e "$OUT" ]] || { echo "$OUT already exists; remove it first to rebuild" >&2; exit 1; }

cp "$RECIPES/renv.lock" "$RECIPES/renv.lock.SOURCE" "$SCRIPT_DIR/"
cat > "$SCRIPT_DIR/patch.def" <<EOF
Bootstrap: localimage
From: $BASE_SIF

%files
    renv.lock /opt/recipe/renv.lock
    renv.lock.SOURCE /opt/recipe/renv.lock.SOURCE

%post
    # Only CMRSS: the other packages are already at the lockfile's versions,
    # which check_image.R confirms below.
    R -e 'renv::install("davidk91919/CMRSS@${CMRSS_SHA}", library = "/usr/local/lib/R/site-library", prompt = FALSE)'
    Rscript /opt/recipe/check_image.R cluster /opt/recipe/renv.lock

%labels
    paper.renv_lock.commit ${PAPER_SHA}
    patched.from jake_cluster-${BASE_TAG}
EOF

echo "building $OUT from $BASE_SIF with CMRSS ${CMRSS_SHA:0:7} (lockfile from paper commit ${PAPER_SHA:0:7})"
apptainer build $BUILD_FLAGS "$OUT" patch.def
echo "built $OUT; set IMAGE_TAG=$TAG in code/simulations/zeta_regret/cluster_env.sh"
