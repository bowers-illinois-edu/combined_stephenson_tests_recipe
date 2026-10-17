import json
import os
import platform
import sys
from pathlib import Path


P3M_BASE = "https://packagemanager.posit.co/cran/__linux__"


def ubuntu_codename() -> str:
    # The Ubuntu codename of the machine running this script (e.g. "noble"),
    # read from /etc/os-release inside the image, so the binary URL follows
    # the image's Ubuntu if the base image is ever bumped.  Standalone
    # testing on macOS has no /etc/os-release and falls back to the codename
    # of the ubuntu:24.04 the Dockerfile uses.
    try:
        for line in Path("/etc/os-release").read_text().splitlines():
            if line.startswith("VERSION_CODENAME="):
                return line.split("=", 1)[1].strip()
    except OSError:
        pass
    print("No VERSION_CODENAME in /etc/os-release; assuming noble (ubuntu:24.04).",
          file=sys.stderr)
    return "noble"


def main() -> int:
    if len(sys.argv) not in (3, 4):
        print("Usage: renv_filter_lock.py <in-lockfile> <out-lockfile> [p3m-date]",
              file=sys.stderr)
        return 2

    src = Path(sys.argv[1])
    dst = Path(sys.argv[2])
    p3m_date = sys.argv[3].strip() if len(sys.argv) == 4 else ""

    data = json.loads(src.read_text())
    packages = data.get("Packages", {})

    # Rewrite the lock's repositories to Posit Package Manager's prebuilt
    # Linux binaries when a snapshot date is given.  CRAN serves Linux
    # packages as source only, so a restore from CRAN compiles every
    # package; Posit's __linux__ snapshots serve them prebuilt, compiled
    # against the same CRAN r-base the Dockerfile installs, and renv
    # reads its repositories from the lockfile, so writing the URL here is
    # what makes renv::restore() use it.  The date pins the snapshot, so a
    # later rebuild fetches the same binaries.  Versions the snapshot no
    # longer lists come from Posit's archive (also prebuilt); the GitHub
    # packages have no binary repository and install from source as before.
    # The Name stays "CRAN" because every package record names its
    # repository "CRAN" and renv matches records to repositories by name.
    if p3m_date:
        url = f"{P3M_BASE}/{ubuntu_codename()}/{p3m_date}"
        data.setdefault("R", {})["Repositories"] = [{"Name": "CRAN", "URL": url}]
        print(f"Repositories rewritten to Posit binaries: {url}", file=sys.stderr)

    # Always remove gurobi from the lockfile - it's installed separately via
    # install.packages() in the Dockerfile to avoid renv cellar issues.
    # The Dockerfile checks KEEP_GUROBI and installs from the local tarball.
    gurobi = packages.get("gurobi")
    if gurobi:
        keep_gurobi = os.environ.get("RENV_KEEP_GUROBI", "1") == "1"
        arch = platform.machine().lower()
        is_x86_64 = arch in {"x86_64", "amd64"}

        if not keep_gurobi:
            print("Removing 'gurobi' from lockfile (RENV_KEEP_GUROBI=0).", file=sys.stderr)
        elif not is_x86_64:
            print(
                f"Removing 'gurobi' from lockfile on unsupported architecture '{arch}'. "
                "Build with `--platform=linux/amd64` if you need Gurobi.",
                file=sys.stderr,
            )
        else:
            print("Removing 'gurobi' from lockfile (will be installed separately from tarball).", file=sys.stderr)
        packages.pop("gurobi", None)

    dst.write_text(json.dumps(data))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
