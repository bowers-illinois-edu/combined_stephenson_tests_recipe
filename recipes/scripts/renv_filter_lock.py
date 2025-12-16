import json
import os
import platform
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: renv_filter_lock.py <in-lockfile> <out-lockfile>", file=sys.stderr)
        return 2

    src = Path(sys.argv[1])
    dst = Path(sys.argv[2])

    data = json.loads(src.read_text())
    packages = data.get("Packages", {})

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
