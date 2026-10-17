# Repository Guidelines

## Project Structure
- `recipes/`: Container build recipe (Docker + Singularity/Apptainer).
  - `recipes/ubuntu/Dockerfile`: two stages, `cluster` (R + the paper's packages, no Gurobi) and `dev` (adds editors, TeX Live, Neovim, Gurobi).
  - `recipes/renv.lock`: copied from the paper repository by `build_ubuntu.sh`; `recipes/renv.lock.SOURCE` records the commit. Do not edit it here.
  - `recipes/scripts/renv_filter_lock.py`: Build-time lockfile filter (drops `gurobi`).
  - `recipes/scripts/check_image.R`: run at the end of each build stage; fails the build unless R and every package match the lock.
- `start_docker.sh`: Convenience script to run the image interactively.
- `home-jwbowers/`: Example home directory mounted into the container.

## Build, Test, and Development Commands
Build the Docker image (from repo root):
```bash
DOCKER_PLATFORM=linux/amd64 KEEP_GUROBI=1 bash recipes/build_ubuntu.sh
```
- `DOCKER_PLATFORM`: defaults to `linux/amd64`, the cluster's architecture.
- `KEEP_GUROBI=0`: leave Gurobi out of the dev image (the cluster image never has it).
- `PAPER_REPO`, `PAPER_REF`: where to copy `renv.lock` from (default `~/repos/combined_stephenson_tests` at `HEAD`).
- `R_DEB_VERSION`: the CRAN Debian build of R (default `4.6.1-6.2404.0`); must match the lock's R version.
- `GITHUB_PAT=...`: not needed; the lock's GitHub packages are public.

Run an interactive shell in the container:
```bash
bash start_docker.sh
# or: docker exec -ti jake_dev bash
```

Build a Singularity/Apptainer image on Linux:
```bash
APPTAINER_TMPDIR=/path/to/tmp singularity build --fix-perms jake_cluster-0.3.sif docker://jwbowers/jake_cluster:0.3
```

## Coding Style & Naming Conventions
- Shell scripts: use `bash`, prefer `set -euo pipefail`, quote variables, and keep indentation consistent.
- Dockerfile changes: keep layers tidy (combine `apt-get` steps, clean `apt` lists) and document new build args.
- Python: PEP 8 / 4-space indentation; keep scripts runnable via `python3`.

## Testing Guidelines
No formal test suite is included; use smoke checks:
- Build succeeds; `check_image.R` runs inside each stage and fails the build on any mismatch with the lock.
- `docker run --rm jwbowers/jake_cluster:0.3 R -q -e 'sessionInfo()'` shows R 4.6.1 and names the BLAS.

## Commit & Pull Request Guidelines
- Commits: short, imperative summaries (e.g., "Update README ...", "Add ...", "Fix ...").
- PRs: describe the motivation, list key commands run (build/smoke test), and note platform-sensitive changes (`DOCKER_PLATFORM`, `KEEP_GUROBI`, lockfile edits).

## Security & Configuration Tips
- Never commit secrets (e.g., `GITHUB_PAT`, license keys).
- Treat `GITHUB_PAT` as sensitive even when passed as a Docker build arg.
