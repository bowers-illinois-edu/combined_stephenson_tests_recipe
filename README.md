A recipe for creating docker and singularity images for the combined stephenson paper
simulations and analyses


```
 DOCKER_PLATFORM=linux/amd64 KEEP_GUROBI=1 bash recipes/build_ubuntu.sh

```

Then, on a linux system the campus cluster in particular. On keeling it seems to work ok without needing to specify a different tmp directory or `--fix-perms`

```
 mkdir -p /projects/illinois/las/pol/jwbowers/repos/combined_stephenson_tests_recipe/recipes/singularity_tmp 
 APPTAINER_TMPDIR=/projects/illinois/las/pol/jwbowers/repos/combined_stephenson_tests_recipe/recipes/singularity_tmp singularity build --fix-perms jake_dev-0.1.sif docker://jwbowers/jake_dev:0.1

## or
##   APPTAINER_TMPDIR=/scratch/jwbowers/singularity_tmp singularity build jake_dev-0.1.sif docker://jwbowers/jake_dev:0.1
```
