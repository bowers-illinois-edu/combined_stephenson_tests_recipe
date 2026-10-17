################################################################################
### check_image.R -- does this image hold the environment the paper's
### renv.lock describes?
###
### Why this file exists.  The image is useful only if the R it carries is the
### R that the paper repository's lockfile records, with every package at the
### recorded version: the reason to compute inside a container is that a
### result should not depend on which machine computed it.  The Dockerfile
### runs this script as the last step of each stage, so an image that does not
### match the lockfile fails to build instead of producing numbers.
###
### Usage:  Rscript check_image.R <cluster|dev> <path to renv.lock>
###
###   cluster  Every package in the lock except gurobi is installed at the
###            lock's version, and gurobi is not installed at all, so that
###            CMRSS's "auto" choice of solver can only pick HiGHS
###            (memo_campus_cluster_2026-10-12.md, Section 3.5).
###   dev      Every package in the lock, gurobi included, is installed at
###            the lock's version.  No Gurobi solve is attempted, because no
###            licence is present when the image is built.
###
### Both modes also require that R's version equals the lock's, that each
### GitHub package was installed from the commit the lock records, that HiGHS
### solves a two-variable integer program, and that
### RENV_CONFIG_AUTOLOADER_ENABLED is FALSE (otherwise the paper repository's
### .Rprofile would start renv inside the container).  The BLAS and LAPACK
### libraries are printed and not checked: whether one study may run on nodes
### with different processors depends on them (memo, Section 6, step 4).
################################################################################

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2 || !args[1] %in% c("cluster", "dev")) {
  stop("usage: Rscript check_image.R <cluster|dev> <path to renv.lock>", call. = FALSE)
}
mode <- args[1]
lock <- renv::lockfile_read(args[2])

## Every failed requirement is collected and reported together, so that one
## build shows everything that is wrong rather than only the first problem.
problems <- character(0)
fail <- function(...) problems <<- c(problems, paste0(...))

### ------ R itself

r_now <- as.character(getRversion())
if (!identical(r_now, lock$R$Version)) {
  fail("R is ", r_now, " but the lock records R ", lock$R$Version)
}

### ------ packages, at the lock's versions

## installed.packages() lists the libraries in .libPaths() order, so the first
## row for a package is the copy that library() would load.  That copy is the
## one that has to match: an older copy further down the path does no harm.
ip <- installed.packages(fields = "RemoteSha")
first <- function(pkg) {
  i <- match(pkg, ip[, "Package"])
  if (is.na(i)) NULL else ip[i, ]
}

expected <- lock$Packages
if (mode == "cluster") expected$gurobi <- NULL

for (pkg in names(expected)) {
  want <- expected[[pkg]]
  have <- first(pkg)
  if (is.null(have)) {
    fail(pkg, " is not installed (the lock records ", want$Version, ")")
    next
  }
  if (!identical(unname(have[["Version"]]), want$Version)) {
    fail(pkg, " is ", have[["Version"]], " but the lock records ", want$Version)
  }
  ## A GitHub package's version number need not change between commits, so
  ## the commit is what identifies the code.
  if (identical(want$Source, "GitHub") &&
      !identical(unname(have[["RemoteSha"]]), want$RemoteSha)) {
    fail(pkg, " was installed from commit ", have[["RemoteSha"]],
         " but the lock records ", want$RemoteSha)
  }
}

if (mode == "cluster" && requireNamespace("gurobi", quietly = TRUE)) {
  fail("gurobi is installed, so CMRSS's 'auto' solver would choose Gurobi, ",
       "which has no licence on the cluster")
}

### ------ HiGHS solves something

## The same problem code/setup_gurobi.R in the paper repository gives Gurobi:
## maximize x + y subject to x + y <= 1, with x and y integers in [0, 1].
## The answer is 1.  A package that installs but cannot solve fails here
## rather than in the middle of a cluster run.
res <- tryCatch(
  highs::highs_solve(L = c(1, 1), lower = c(0, 0), upper = c(1, 1),
                     A = matrix(c(1, 1), nrow = 1), lhs = -Inf, rhs = 1,
                     types = c("I", "I"), maximum = TRUE),
  error = function(e) e
)
if (inherits(res, "error")) {
  fail("HiGHS test solve stopped with an error: ", conditionMessage(res))
} else if (!identical(as.integer(res$status), 7L) ||
           abs(res$objective_value - 1) > 1e-9) {
  ## 7 is HiGHS's code for an optimal solution (CMRSS checks the same code).
  fail("HiGHS test solve returned status ", res$status, " (", res$status_message,
       ") and objective ", res$objective_value, "; expected status 7 and 1")
}

### ------ renv must stay out of the way

if (!identical(Sys.getenv("RENV_CONFIG_AUTOLOADER_ENABLED"), "FALSE")) {
  fail("RENV_CONFIG_AUTOLOADER_ENABLED is '",
       Sys.getenv("RENV_CONFIG_AUTOLOADER_ENABLED"), "', not FALSE")
}

### ------ report

si <- sessionInfo()
cat("check_image.R, mode ", mode, "\n", sep = "")
cat("  R:      ", r_now, "\n", sep = "")
cat("  BLAS:   ", si$BLAS, "\n", sep = "")
cat("  LAPACK: ", si$LAPACK, "\n", sep = "")
cat("  packages checked against the lock: ", length(expected), "\n", sep = "")

if (length(problems) > 0) {
  cat("\nThe image does not match the lock:\n",
      paste0("  - ", problems, collapse = "\n"), "\n", sep = "")
  quit(status = 1)
}
cat("  every requirement met\n")
