A recipe for creating docker and singularity images for the combined stephenson paper
simulations and analyses

## Two images

`recipes/build_ubuntu.sh` builds two images from `recipes/ubuntu/Dockerfile`
(see `memo_campus_cluster_2026-10-12.md` for the plan behind them):

- `jwbowers/jake_cluster`: R at the version the paper repository's `renv.lock`
  records (4.6.1 as of 2026-10-12) and every package in that lock except
  `gurobi`. Cluster runs use HiGHS, which needs no licence.
- `jwbowers/jake_dev`: the same, plus editors, TeX Live, Node, Neovim and
  Gurobi 13.0.3, for working in a container on the laptop.

The lockfile is not maintained here. The build script copies it from
`~/repos/combined_stephenson_tests` as committed at `PAPER_REF` (default
`HEAD`) and writes the commit to `recipes/renv.lock.SOURCE`. Each image is
tagged `0.3` and `0.3-<first seven characters of that commit>`. Each build
stage ends by running `recipes/scripts/check_image.R`, which stops the build
unless R and every package match the lock.

The packages install from Posit Package Manager's prebuilt Linux binaries
for the image's Ubuntu, dated the day the paper repository last changed its
lockfile (`P3M_DATE`; the build script prints the date and records it in
`recipes/renv.lock.SOURCE`). CRAN serves Linux packages as source only, so
without this the restore compiles all of them, under emulation on this
laptop. `P3M_DATE=none` compiles from source. The three GitHub packages
(CMRSS, QIoT, RIQITE) have no binary repository and always install from
source.


## Building

Neovim is installed to ensure a modern version (>= 0.11). The build will try `ppa:neovim-ppa/stable`, then `ppa:neovim-ppa/unstable`, and finally fall back to the official GitHub release tarball if the PPAs do not provide a new enough version for Ubuntu 24.04.

The image also installs common AstroNvim prerequisites via apt (notably `nodejs`/`npm`, `python3` venv/pip tooling, `lua5.1`/`luarocks`, `ripgrep`, `fd`, `fzf`, and TeX tooling like `texlive` + `latexmk`).

Override the pinned fallback version with:

```bash
docker build --build-arg NEOVIM_VERSION=0.11.0 --build-arg NEOVIM_MIN_VERSION=0.11.0 ...
```


```
 DOCKER_PLATFORM=linux/amd64 KEEP_GUROBI=1 bash recipes/build_ubuntu.sh

```

The dev image downloads Gurobi 13.0.3 during the build, checks it against its SHA-256, installs it under `/opt/gurobi1303`, sets `GUROBI_HOME`/`PATH`, and registers the shared libraries via `ldconfig`. `KEEP_GUROBI=0` leaves it out. The cluster image never has Gurobi.

## Gurobi Sanity Check

After building, verify the solver is visible inside the container:

- Docker:
  ```bash
  docker run --rm -it jwbowers/jake_dev:0.3 grbprobe
  ```

- Apptainer/Singularity (Linux):
  ```bash
  apptainer exec jake_dev-0.3.sif grbprobe
  # If needed:
  apptainer exec jake_dev-0.3.sif /opt/gurobi1303/linux64/bin/grbprobe
  ```

## Gurobi Licensing (Runtime)

The dev image includes the Gurobi binaries/libraries, but you still need a license at runtime. A machine-tied academic licence does not work inside a container; Gurobi in a container needs a WLS licence (`memo_campus_cluster_2026-10-12.md`, Section 9):

- Put a license file at `~/.gurobi/gurobi.lic` on the host (Apptainer typically bind-mounts `$HOME`), or
- Set `GRB_LICENSE_FILE`, e.g.:
  ```bash
  export GRB_LICENSE_FILE=$HOME/.gurobi/gurobi.lic
  # or a token/server license:
  export GRB_LICENSE_FILE=27000@your-license-server
  ```

## Local Testing on macOS (Docker Desktop)

Docker Desktop runs Linux containers inside a VM. If you are on Apple Silicon, prefer building/running as `linux/amd64` (the bundled Gurobi tarball is `linux64`).

If you see `no matching manifest for linux/amd64`, Docker is trying to pull an image tag that does not include an `amd64` build. Build the image locally with `DOCKER_PLATFORM=linux/amd64` (or push an amd64 build to the registry).

Run an interactive shell while mounting your local Neovim config + optional Gurobi license:

```bash
docker run --pull=never --rm -it --platform linux/amd64 \
  -v "$HOME/.config/nvim:/home/$USER/.config/nvim:ro" \
  -v "$HOME/.gurobi:/home/$USER/.gurobi:ro" \
  -e GRB_LICENSE_FILE=/home/$USER/.gurobi/gurobi.lic \
  jwbowers/jake_dev:0.3 bash -lc 'mkdir -p "$HOME/.local/state" "$HOME/.local/share" "$HOME/.cache" && exec bash'
```

This uses your host `~/.config/nvim` but lets the container manage `~/.local/*` and `~/.cache/*`. On macOS, bind-mounting nested paths like `~/.local/share/nvim` can create root-owned parent directories inside the container and lead to errors like `Cannot create directory ~/.local/state: permission denied`.

Inside the container, sanity-check Gurobi + Neovim:

```bash
grbprobe
nvim --headless +"lua print(vim.fn.stdpath('config'))" +"lua print(vim.fn.stdpath('data'))" +q
```

Then, on a linux system the campus cluster in particular. On keeling it seems to work ok without needing to specify a different tmp directory or `--fix-perms`

```
 mkdir -p /projects/illinois/las/pol/jwbowers/repos/combined_stephenson_tests_recipe/recipes/singularity_tmp 
 APPTAINER_TMPDIR=/projects/illinois/las/pol/jwbowers/repos/combined_stephenson_tests_recipe/recipes/singularity_tmp singularity build --fix-perms jake_cluster-0.3.sif docker://jwbowers/jake_cluster:0.3

## or
##   APPTAINER_TMPDIR=/scratch/jwbowers/singularity_tmp singularity build jake_cluster-0.3.sif docker://jwbowers/jake_cluster:0.3
```
