# Running the paper's long computations on the Illinois Campus Cluster

Plan written 2026-10-12, after reading this repository, the paper repository
(`~/repos/combined_stephenson_tests`), Felipe Menanteau's four repositories and
the Campus Cluster documentation. Jake's decisions of 2026-10-12 are in
Section 3; the decisions still open are in Section 4.

## 1. The problem this plan addresses

The paper's long computations run on koelsch, a 40-core machine with no queue
on which Gurobi is licensed. The regret study now running there
(`code/simulations/zeta_regret/` in the paper repository) is the current
example. Its timing pilot of 20 replications per cell put stage 1 at about 8.4
hours and stage 2 at about 11.8 hours on 38 workers, so the whole study needs
about (8.4 + 11.8) x 38 = 768 core-hours. A study ten times that size would
take koelsch more than a week.

The Illinois Computes partition of the Campus Cluster has 22 CPU nodes, each
with two 64-core AMD 7713 processors (128 cores) and 512 GB of memory. Its
standard allocation is 100,000 core-hours, so the regret study would use under
1 percent of it. On four nodes (512 cores) the study would take about
768 / 512 = 1.5 hours plus time waiting in the queue, if a cluster core runs
as fast as a koelsch core. Nobody has compared the two.

The goal is a setup in which Jake can tell Claude, working in the paper
repository, to send a long run to the cluster instead of koelsch, with the
same R, the same packages and the same results. The image is what makes the
software the same: once it exists, the laptop, koelsch and the cluster can all
run it, so a result does not depend on which machine's own installation
computed it.

## 2. Felipe's workflow, and what the paper repository already has

Felipe's recipe repositories (`spt3g_ingest-recipes`, `spt3g_cutter-recipes`)
build a Docker image with his analysis package cloned in at a release tag. He
names the image with that version and a git hash (`ubuntu_0.6.0_<rev>`),
pushes it to a registry, converts it once to Apptainer's single-file image
format (`.sif`), and keeps that file on the cluster under
`/projects/caps/spt3g/singularity`. Apptainer is the cluster's container
program; it was called Singularity, and `singularity` still runs it.

His jobs repository (`spt3g_jobs`) writes a list with one line per task and a
Slurm array job. An array job is one `sbatch` submission that starts N copies
of the same script and gives each copy its index in `SLURM_ARRAY_TASK_ID`.
Copy i reads line i of the list and runs
`singularity exec --bind /projects image.sif <command>`. A YAML file holds the
partition, time, memory and cores per task. To rerun failed tasks he
resubmits only their line numbers (`--redo_index`).

The paper repository already does most of this on koelsch:

- `code/applications/mdrc/run_hunt_koelsch.sh` writes a job list, skips work
  already on disk, retries failures and logs each task. GNU parallel runs the
  list on koelsch's cores; on the cluster a Slurm array would run it across
  nodes.
- The regret study's stage 1 tests the sharp null hypothesis. Its stage 2
  tests whether at least a tenth or at least half of the treated units
  gained, and whether at least a tenth lost. Each stage is 23 x 3 = 69 cells:
  23 patterns of individual treatment effects times 3 combinations of design
  and score (completely randomized with Stephenson scores, completely
  randomized with polynomial scores, stratified with polynomial scores).
- `zr_run_cell()` writes one file per cell, skips a file already on disk, and
  writes to `.part` before renaming, so a crash cannot leave a partial file
  that a rerun would skip.
- `sim_seed()` in `code/parallel_seeds.R` makes replication i's data depend
  only on its loop indices (master seed, pattern, design and i), so a cell
  computed on a cluster node draws the same data as on koelsch.

What the paper repository lacks for the cluster is an image that matches its
`renv.lock`, a solver that works on cluster nodes, and a Slurm script in place
of GNU parallel.

## 3. Decisions made on 2026-10-12

### 3.1 Cluster runs use HiGHS, not Gurobi

Jake's licences for Gurobi are each tied to one machine: koelsch's licence
names koelsch's hardware ID and works nowhere else. Every cluster node is a
different machine, so none of these licences works there. Gurobi's routes to
a cluster licence are an academic WLS licence (checked over the internet at
each use) or a campus site licence that a system administrator must request
(Section 9 records what was found about these two routes). HiGHS, an open-source solver
that CMRSS already supports, needs no licence, and `highs` 1.14.0-2 is in the
paper's `renv.lock`. Jake proposed HiGHS for cluster runs on 2026-10-12, and
this plan adopts it.

Choosing HiGHS has four consequences for the code and the results.

First, HiGHS and Gurobi do not always return the same bound. The benchmark in
the paper repository's `data/solver_benchmark.rds` (1,000 units, 500 treated)
saved 11 lower confidence bounds on quantiles of the individual effects for
each solver. Six of the 11 are minus infinity under both, so five can be
compared. With the degree-2 polynomial statistic (Wilcoxon's), the two
solvers gave the same five bounds. With degree 10, four of
the five differed by 0.01:

| quantile row | Gurobi | HiGHS |
|---|---|---|
| 7 | 0.11 | 0.12 |
| 8 | 0.55 | 0.56 |
| 9 | 0.92 | 0.93 |
| 10 | 1.30 | 1.30 |
| 11 | 1.77 | 1.78 |

So a study computed with HiGHS is not to be pooled with one computed with
Gurobi, and within one study every candidate vector of degrees must use the
same solver. The regret study now running on koelsch uses Gurobi; a HiGHS
rerun on the cluster is a separate study.

Second, the solver has to be named, not left to CMRSS. The regret study
passes `opt.method = "ILP_auto"` (`pvalues.R`, line 92). CMRSS reads "auto"
as Gurobi whenever the `gurobi` R package is installed, whether or not a
licence is present. A cluster run must pass `opt.method = "ILP_highs"`, and
`stage.R` (line 48) must stop requiring Gurobi for stage 2. Only the
stratified cells of stage 2 call a solver at all: their p-value needs an
integer program to place the units allowed any effect where they make the
statistic smallest, and in the completely randomized design a formula gives
that placement directly.

Third, HiGHS is slower on the larger degrees. In the same benchmark its
integer programs took 11.3 seconds at degree 10 against Gurobi's 7.1, and 7.7
against 6.5 at degree 2. The stage-2 timings above were measured with Gurobi,
so a HiGHS run will take longer than they suggest.

Fourth, the HiGHS thread count needs the same check Gurobi needed. CMRSS
passes HiGHS only `log_to_console = FALSE`, and HiGHS's `threads` option
defaults to automatic. Gurobi's default took every core for each solve, and
under parallel workers that gave a load average of 158 on the laptop's 14
cores (`code/RUNNING_REMOTELY.md`). Whether HiGHS does anything similar under
forked R workers has not been measured. The first cluster pilot should record
the load average; if it exceeds the core count, CMRSS needs a
`CMRSS.highs.threads` option like its Gurobi one.

### 3.2 Parallelism inside R

Each Slurm task runs the existing `mclapply` over the cores Slurm gives it
(`ZR_WORKERS=$SLURM_CPUS_PER_TASK`), as on koelsch. Jake raised
parallelism inside R as a way to avoid running Gurobi on many nodes. It
would not have been enough, because a Gurobi licence tied to koelsch fails on whichever cluster node a job runs on, whether
the job runs one R process or many, because that node is not koelsch. With HiGHS no licence ties the work to one
machine, so how many nodes a study uses is a choice about speed and queue time
only. One node gives 128 cores, 128 / 40 = 3.2 times koelsch's 40. A Slurm
array of one task per cell spreads the 69 cells of a stage over several
nodes, which multiplies that again by the number of nodes Slurm grants.

### 3.3 This repository is brought up to date

Jake judged this repository out of date on 2026-10-12 and asked that its
versions be updated. Section 5 lists what is behind the paper repository.

### 3.4 koelsch keeps running outside the image for now

koelsch has Docker, but on 2026-10-12 the account `jwbowers` was not in its
`docker` group. Jake expects to get that access, and decided on 2026-10-12 to
keep running on koelsch outside Docker in the meantime. So two environments
coexist: koelsch's conda R with Gurobi, and the image with HiGHS.
This plan adds a rule, which awaits Jake's confirmation: a study runs
entirely in one of them, never split across the two, and its result files
record which one (the image tag, or koelsch's conda environment
`mambaR461`).

### 3.5 The image's lockfile, and Gurobi

Jake approved on 2026-10-12 building the image from the paper repository's
lockfile, copied in at build time with its commit recorded, and a cluster
image without Gurobi (`KEEP_GUROBI=0`, which `renv_filter_lock.py` supports by
dropping `gurobi` from the lockfile). Without Gurobi installed,
`opt.method = "ILP_auto"` can only choose HiGHS there. The laptop image keeps
Gurobi for a WLS licence later.

## 4. Decisions still open

1. Where development happens. The Mac is arm64 and the image is amd64 (the
   cluster nodes are x86), so on the laptop the container runs under
   emulation, more slowly than native R. The proposal is to keep developing
   natively under renv and run the container on the laptop only for a short
   test before submitting. Felipe instead develops inside the container.
   That practice gives the laptop the same binaries as the cluster, run under
   emulation.
2. Where the Slurm scripts go. The proposal is the paper repository, beside
   `run_hunt_koelsch.sh`, because they call its scripts by path and must
   change when those scripts change. Felipe keeps his in a separate jobs
   repository, which suits one image serving many job configurations.
3. Whether the paper's empirical bounds stay on Gurobi. They run on the
   laptop or koelsch and do not need the cluster, so the HiGHS decision does
   not force a change; `sre_elec_teacher_run.R` names `ILP_gurobi`
   explicitly.

## 5. What the image in this repository needs

| | this repository's `recipes/renv.lock` | paper repository's `renv.lock` |
|---|---|---|
| R | 4.5.2 | 4.6.1 |
| packages | 136 | 150 |
| CMRSS | 0.2.0 | 0.2.11 |
| gurobi (R package) | 12.0-3 | 13.0-3 |
| highs | absent | 1.14.0-2 |

An image built from this repository's lockfile would run CMRSS 0.2.0 while
koelsch runs 0.2.11, so the two machines would compute with different code,
and it would have no HiGHS. The proposed changes:

- The build copies `renv.lock` from the paper repository at a stated commit
  and records that commit, the way the regret study's `simlib/SOURCE` file
  records the commit its pattern library was copied from.
- The Dockerfile pins R at 4.6.1. It now installs whatever `r-base` CRAN's
  apt repository serves on the day of the build.
- The Gurobi tarball becomes 13.0.3, to match the `gurobi` 13.0-3 R package
  in the paper's lockfile, if the image keeps Gurobi at all.
- A second, smaller image for the cluster leaves out TeX Live, the editors
  and Node, which the current Dockerfile installs in its first layer.
- The cluster image sets `RENV_CONFIG_AUTOLOADER_ENABLED=FALSE`. Otherwise the
  paper repository's `.Rprofile` starts renv, which looks for a project
  library that does not exist on the cluster. (`renv/activate.R` reads this
  variable and skips activation when it is FALSE.)
- `docker run ... Rscript -e 'sessionInfo()'` inside the built image names its
  BLAS, the linear-algebra library R calls. Section 6, step 4, says why that
  matters.

These changes were made on 2026-10-12 in `recipes/ubuntu/Dockerfile`,
`recipes/build_ubuntu.sh` and `recipes/scripts/check_image.R`, and the
documentation was brought up to tag 0.3. Neither image had been built when
this was written.

Building an amd64 image on the arm64 laptop runs under emulation, and
`renv::restore()` compiles each of the 150 packages from source. Precompiled
Linux packages from Posit Package Manager, or a build on a native amd64
machine, would shorten it. Neither has been tried.

[2026-10-17] The Posit route is wired in and verified against the server,
though not yet through a Docker build. `renv_filter_lock.py` rewrites the
copied lock's repository to Posit's prebuilt Linux binaries for noble,
dated the day the paper repository last changed its lockfile (`P3M_DATE`;
"none" restores the source-only build), because `renv::restore()` reads its
repositories from the lockfile. On the 2026-10-15 snapshot, 129 of the 146
CRAN packages in the paper's lock are prebuilt at the locked version; the
other 17 are older than current CRAN and come from Posit's archive, which
serves them prebuilt as well (verified for MASS 7.3-65 and coin 1.4-5). The
three GitHub packages still install from source. A native amd64 build
remains untried.

## 6. The steps, in order

1. On a cluster login node, three commands answer what the web pages do not.
   `/sw/cc.users/tools/my.accounts` prints Jake's Slurm account names.
   `sinfo -s -o "%.25R %.12l %.12L %.5D"` prints the partitions open to him
   and their time limits. `sinfo -N --format="%R (%N): %f" -S %R` prints each
   node's features, including processor type.
2. Rebuild the image as in Section 5, push it, and build the `.sif` under
   `/projects/illinois/las/pol/jwbowers/` inside a short interactive job
   (`srun ... --pty bash`), because the cluster kills login-node processes
   after 30 CPU-minutes. Set `APPTAINER_CACHEDIR` to a directory under
   `/projects`, because the default cache in the home directory counts
   against its 100 GB quota.
3. Write the Slurm array script in the paper repository.
   - One array task per cell. The stage scripts now loop over every cell in
     one R process, so each task needs a small R entry point that takes one
     cell's stage, pattern, design and family from the command line and calls
     `zr_run_cell()`, the way `bounds_hunt.R` takes one MDRC cell.
   - Each task sets `OPENBLAS_NUM_THREADS=1`, `OMP_NUM_THREADS=1`,
     `RENV_CONFIG_AUTOLOADER_ENABLED=FALSE` and
     `ZR_WORKERS=$SLURM_CPUS_PER_TASK`, and runs from the repository root, as
     the koelsch scripts do.
   - The script refuses to run from a checkout with uncommitted changes, and
     every output file records the commit and the image tag. Felipe gets the
     same record by building the code into the image.
   - Rerunning the array resubmits every cell, and cells already on disk are
     skipped by `zr_run_cell()`, which does what `--redo_index` does for
     Felipe.
4. Check that the image gives the same numbers on two machines with
   different processors before trusting any cluster number. The image fixes
   the software: R, every package, the BLAS (the linear-algebra library R
   calls for sums such as `crossprod()`) and the solver. It does not fix the
   processor, and some libraries choose their routines by processor at run
   time. OpenBLAS does; whether HiGHS does has not been checked.
   `RUNNING_REMOTELY.md` records a change in the order of such sums moving 4
   of 40 quantile bounds in one of the paper repository's tests.
   - The check runs the same image on two cluster nodes with different
     processors, on the first 200 replications of one stratified stage-2
     cell, and compares the two files replication by replication. The
     Illinois Computes nodes have AMD EPYC 7713 processors; the secondary
     queue reaches nodes with other processors, and `--constraint` (the Slurm
     option that limits a job to nodes with a named feature) picks one.
     Because replication i is seeded from i alone, both files hold the same
     200 experiments, so a difference can come only from the processors.
   - It does not use results from koelsch's own conda R (Section 3.4). Those
     come from a different environment and, for the stratified cells, a
     different solver, so a comparison with them would mix those changes with
     the change of processor. When koelsch can run the image, the check can
     add koelsch's Intel Xeon E5-2650 v3 as a third processor.
   - `code/RUNNING_REMOTELY.md` lists a comparison of one simulation computed
     on two machines as the one cross-machine check nobody has made. This is
     that check, made with the image.
   - The same file says never to split one simulation across machines whose
     arithmetic may differ, and the cells of one study would run on several
     cluster nodes. Every CPU node of the Illinois Computes partition has the
     same AMD 7713 processors. The secondary queue runs jobs on idle nodes of
     every processor type, so if the check finds that processor type changes
     results, a study run there should name one type with `--constraint`,
     the Slurm option that limits a job to nodes with a named feature.
5. Add a cluster section to the paper repository's `code/RUNNING_REMOTELY.md`
   with the same parts as its koelsch section (what the machine has, shell
   setup, launch, copying back, what was checked), and one line in its
   `CLAUDE.md` saying when to use the cluster.

## 7. Writing results as they finish

The regret study already writes one file per cell. Stage 2 averages
11.8 x 38 / 69 = 6.5 core-hours per cell under Gurobi, which is about six
minutes on a 64-core task. The 23 stratified cells take longer than the
average, and HiGHS makes them slower still; a cell taking five times the
average would finish in about 5 x 6 = 30 minutes. So cell files would appear while
the rest of the stage runs, and `summarize.R` can read whatever exists, which
is enough to prototype figures and catch errors early.

The cell files are `.rds`, which only R reads. Writing each one also with
`write.csv` would make it plain text, readable by any tool while the run
continues. New scripts can follow the same design: cut the work into units
that finish in minutes to an hour, and write one file per unit.

## 8. How Claude in the paper repository would use the cluster

The cluster requires Duo at login and does not accept users' own SSH keys, so
Claude cannot log in by itself. The cluster documentation recommends an SSH
ControlMaster, an ssh setting that lets later commands reuse one logged-in
connection. Jake opens the first connection and approves the Duo prompt;
Claude's `ssh icc 'sbatch ...'` commands then reuse it until it closes.

A rule for the paper repository's `CLAUDE.md` might read: use koelsch for a
run that finishes overnight there, and the cluster for a longer run or when
koelsch is busy. koelsch has no queue and no 4-hour limit. The secondary queue
limits each job to 4 hours, far above tasks of minutes; the Illinois Computes
partition's own limit is one of the facts step 1 looks up.

The MDRC frames (the trial data from MDRC's restricted-use deposit at ICPSR,
prepared for the bounds search in the paper repository's
`code/applications/mdrc/`) are restricted-use. The cluster's storage page forbids HIPAA
data, but whether files under a data-use agreement may go there is set by the
MDRC agreement, not by the cluster. Until Jake checks it, they stay on
koelsch.

Storage on the cluster: home (`/u`, 100 GB, snapshotted), project space
(`/projects`, not purged), and scratch (`/scratch`, 10 TB, files unread for 30
days are purged). Images, checkouts and results belong under `/projects`;
results are copied back with `rsync`, as from koelsch.

## 9. What was found about Gurobi on clusters, kept in case it is needed later

- Gurobi says Named-User Academic licences, the machine-tied kind, are "not
  recommended for use in a cluster with many nodes."
- Gurobi's academic WLS page (updated January 2026) says a WLS licence "runs on
  machines and containers," needs Gurobi 10 or later and an internet
  connection during use, and lasts 90 days, renewable. It states no limit on
  how many solves can run at once.
- In 2022 a user running under Apptainer got Gurobi's error 10024, and Gurobi
  staff replied that WLS did not work under Singularity. Gurobi's article on
  error 10024 gives its cause as a WLS licence used with a Gurobi version
  before 10.0, and the fix as version 10 or later. Gurobi 12.0.3 and 13.0.3
  are both past that.
- An educational site licence runs from a central token server and must be
  requested by a system administrator. Whether the Campus Cluster has one is
  answered by `module avail 2>&1 | grep -i gurobi` on a login node, or by
  asking the cluster's staff.
- Gurobi staff have written that machine-tied academic licences do not work
  inside Docker, so Gurobi in a laptop container would also need WLS.

## 10. Where the work stands at the end of 2026-10-12, and what comes next

### 10.1 State

Committed in this repository: this memo. Changed but not committed, waiting
for a build that passes:

- `recipes/ubuntu/Dockerfile` (the `cluster` and `dev` stages of Section 5)
- `recipes/build_ubuntu.sh` (copies the paper's `renv.lock`, checks the R
  build, tags `0.3` and `0.3-<paper commit>`)
- `recipes/scripts/check_image.R` (new; run at the end of each stage)
- `recipes/.dockerignore` (new)
- `recipes/renv.lock` and `recipes/renv.lock.SOURCE` (the paper's lockfile at
  commit e45e34a, copied with `PREPARE_ONLY=1`)
- `README.md`, `AGENTS.md`, `CLAUDE.md`, `start_docker.sh`, `start_docker_2.sh`
  (tag 0.3 and the two images)

Tested without Docker: `check_image.R` on the laptop against the paper
repository's renv library (all 150 packages match; an altered lock, and
gurobi present in cluster mode, are each reported), and `build_ubuntu.sh`
(shell syntax, the R-build guard, the copied lock identical to the paper's,
149 packages after filtering). Not yet built: the Dockerfile.

[2026-10-17] The Dockerfile is built. Both images are tagged 0.3 and
0.3-539edad, the paper repository's lockfile commit. The Posit binaries of
Section 5 replaced the hours of source compilation: 141 packages installed
prebuilt, five from source (the GitHub packages, renv and estimatr), the
package stage 11 minutes. One fix was needed: step 7 created the wheel
group with addgroup, which ubuntu:24.04's base image does not ship; it now
uses groupadd. check_image.R passed in both stages, and HiGHS solved the
test problem inside the running cluster image. The Gurobi 12 tarballs were
deleted from the repository.

### 10.2 Next steps, in order

1. Start Docker Desktop, then run `bash recipes/build_ubuntu.sh` from this
   repository. It builds `cluster` and then `dev`, and takes hours, because
   the amd64 image builds under emulation and renv compiles 150 packages from
   source. `TARGETS=cluster` builds the cluster image alone. If the paper
   repository's lockfile has changed since e45e34a, the build takes the new
   one and records its commit.
2. If both builds finish, commit the files listed in 10.1. Jake decides
   whether to delete the unused Gurobi 12 tarballs
   (`recipes/ubuntu/gurobi12.0.3_linux64.tar.gz`, and the tracked
   `recipes/renv/cellar/gurobi/gurobi_12.0-3.tar.gz`).
3. Push `jwbowers/jake_cluster` under both tags to Docker Hub.
4. On a Campus Cluster login node, run the three lookups of Section 6, step
   1: account names, partitions and their time limits, and node features.
5. Build the `.sif` from the pushed tag inside an interactive job, with
   `APPTAINER_CACHEDIR` under `/projects` (Section 6, step 2; the build script
   prints the command).
6. In the paper repository: pass `opt.method = "ILP_highs"` for cluster runs,
   stop `stage.R` from requiring Gurobi for stage 2, write the one-cell entry
   point and the Slurm array script (Section 6, step 3), and record the load
   average in the first cluster pilot to see whether HiGHS needs a thread cap
   (Section 3.1).
7. Run the processor check of Section 6, step 4.
8. Add the cluster section to the paper repository's
   `code/RUNNING_REMOTELY.md` and the line in its `CLAUDE.md` (Section 6,
   step 5).

### 10.3 Questions still open for Jake

- Confirm the rule of Section 3.4: a study runs entirely on koelsch's own R
  or entirely in the image, and its results record which.
- The three decisions of Section 4: where development happens, where the
  Slurm scripts go, and whether the paper's empirical bounds stay on Gurobi.
- Access to koelsch's `docker` group, which would let koelsch run the image
  and join the processor check.

## 11. Sources

- Felipe's repositories: https://github.com/CMB-NCSA/spt3g_jobs,
  https://github.com/CMB-NCSA/spt3g_ingest-recipes,
  https://github.com/CMB-NCSA/spt3g_cutter-recipes,
  https://github.com/CMB-NCSA/spt3g_ingest
- Campus Cluster documentation: https://docs.ncsa.illinois.edu/systems/icc/en/latest/
  (pages user_guide/containers, running_jobs, storage_data, accessing)
- Illinois Computes on the Campus Cluster:
  https://campuscluster.illinois.edu/access/illinois-computes/
- Gurobi, academic WLS licence:
  https://support.gurobi.com/hc/en-us/articles/13210193318033
- Gurobi, Gurobi on multiple computers for academic research:
  https://support.gurobi.com/hc/en-us/articles/360040995151
- Gurobi community, Gurobi in an Apptainer/Singularity container (2022):
  https://support.gurobi.com/hc/en-us/community/posts/6598455238545
- Gurobi, error 10024:
  https://support.gurobi.com/hc/en-us/articles/13235765567505
- Gurobi community, Gurobi in a Docker container:
  https://support.gurobi.com/hc/en-us/community/posts/4406485885841
