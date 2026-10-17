# Handoff to the paper repository: first cluster runs

Written 2026-10-17, after the image was built, pushed to Docker Hub, and
built into a .sif on the cluster.  The plan behind all of it is
`memo_campus_cluster_2026-10-12.md` in this repository; this note records
what exists now and what the paper repository's first cluster jobs are, so
a session working in `~/repos/combined_stephenson_tests` can start from
facts instead of rediscovering them.

## What exists, as of 2026-10-17

- Image: `jwbowers/jake_cluster:0.3-539edad` on Docker Hub.  R 4.6.1 and
  the paper repository's `renv.lock` at commit `539edad` (CMRSS 0.2.19),
  every package at the locked version, no Gurobi.  The version check
  (`recipes/scripts/check_image.R` in this repository) passed during the
  build, and the image ran identically on the laptop and, through
  Apptainer, on a cluster node (jobs 11598027 and 11598222, 2026-10-17):
  same R, same BLAS and LAPACK, and a HiGHS solve in both.
- On the cluster: `/projects/illinois/las/pol/jwbowers/images/` holds the
  `.sif` and the script that built it; the Apptainer cache is
  `/projects/illinois/las/pol/jwbowers/apptainer_cache`.  A job runs the
  image with
  `apptainer exec --bind /projects /projects/illinois/las/pol/jwbowers/images/jake_cluster-0.3-539edad.sif <command>`.
- Slurm facts, looked up 2026-10-17: account `jwbowers-ic`; partition
  `IllinoisComputes` --- 22 nodes, each two AMD EPYC 7713 processors
  (128 cores) and 512 GB, all identical, so one study may spread its cells
  across them (memo Section 6 step 4).  Per-job time limit 3 days, but the
  default is 30 minutes, so every job must ask for time explicitly.  Forty
  jobs per user at once, so a 69-cell array runs in waves.  The
  `secondary` partition (4-hour limit, Intel G6148 nodes) is the
  different-processor pool for the cross-processor check.
- From the laptop: `ssh cc` reaches the cluster.  ControlMaster is already
  configured, so after Jake opens the connection once and approves Duo,
  agents run `ssh cc '...'` with no further prompts until the master
  connection closes.

## What the paper repository still needs, in order

These are memo Section 6, steps 3 to 5; none of them exists yet.

1. The one-cell R entry point: a small script taking one cell's stage,
   pattern, design and family from the command line and calling
   `zr_run_cell()`, the way `bounds_hunt.R` takes one MDRC cell.
2. The Slurm array script, one array task per cell, setting
   `OPENBLAS_NUM_THREADS=1`, `OMP_NUM_THREADS=1`,
   `RENV_CONFIG_AUTOLOADER_ENABLED=FALSE` and
   `ZR_WORKERS=$SLURM_CPUS_PER_TASK`, running from the repository root.
   It refuses to run from a checkout with uncommitted changes, and every
   output file records the commit and the image tag
   (`0.3-539edad`).  Rerunning the array is safe: `zr_run_cell()` skips
   cells already on disk.
3. Cluster runs pass `opt.method = "ILP_highs"`, and `stage.R` must stop
   requiring Gurobi for stage 2 (memo Section 3.1).  A HiGHS study is
   never pooled with the Gurobi study running on koelsch.
4. The first pilot on one cell records the load average, to see whether
   HiGHS takes more threads than Slurm gave the task (memo Section 3.1).
5. The processor check: the same image on an `IllinoisComputes` node and
   on a `secondary` G6148 node, first 200 replications of one stratified
   stage-2 cell, compared replication by replication (memo Section 6
   step 4).
6. A cluster section in `code/RUNNING_REMOTELY.md` and one line in the
   paper repository's `CLAUDE.md` saying when to use the cluster instead
   of koelsch (memo Section 6 step 5, Section 8).

## Rules that must survive into those scripts

- A study runs entirely in one environment --- the image on the cluster, or
  koelsch's own conda R --- never split across the two, and its results
  record which (memo Section 3.4, awaiting Jake's confirmation).
- The MDRC restricted-use frames stay on koelsch until Jake checks the
  data-use agreement (memo Section 8).
- Results are copied back with rsync, as from koelsch; images, checkouts
  and results live under `/projects`, never in the 100 GB home directory.
