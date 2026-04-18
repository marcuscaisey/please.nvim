import collections
import json
import re
import subprocess
import sys


def run(*args):
    try:
        result = subprocess.run([*args], capture_output=True, check=True, text=True)
    except subprocess.CalledProcessError as e:
        msg = f"'{' '.join(args)}' exited with code {e.returncode}\nstdout: {e.stdout}\nstderr: {e.stderr}"
        print(msg)
        sys.exit(e.returncode)
    return result.stdout.strip()


releases_json = run("gh", "api", "/repos/neovim/neovim/releases", "--paginate")
releases = json.loads(releases_json)
latest_patches_by_major_minor = collections.defaultdict(int)
for release in releases:
    if release["draft"] or release["prerelease"]:
        continue
    tag_name = release["tag_name"]
    if not (match := re.fullmatch(r"v(\d+)\.(\d+)\.(\d+)", tag_name)):
        continue
    major, minor, patch = (int(n) for n in match.groups())
    latest_patch = latest_patches_by_major_minor[(major, minor)]
    latest_patches_by_major_minor[(major, minor)] = max(patch, latest_patch)
expected_versions = []
for major_minor, latest_patch in sorted(latest_patches_by_major_minor.items())[-2:]:
    expected_versions.append((*major_minor, latest_patch))
if (min_expected_version := expected_versions[0])[2] != 0:
    min_supported_version = (min_expected_version[0], min_expected_version[1], 0)
    expected_versions.insert(0, min_supported_version)

targets_result = run("./pleasew", "query", "filter", "--include", "neovim_toolchain:*")
targets = targets_result.splitlines()
actual_versions = []
for target in targets:
    version = run("./pleasew", "query", "print", target, "--label", "neovim_toolchain:")
    major, minor, patch = (int(n) for n in version.split("."))
    actual_versions.append((major, minor, patch))
actual_versions.sort()

expected_strs = (
    f"{major}.{minor}.{patch}" for major, minor, patch in expected_versions
)
print(f"Plugin should be tested against Neovim versions {', '.join(expected_strs)}")
actual_strs = (
    f"{major}.{minor}.{patch}" for major, minor, patch in actual_versions
)
print(f"Repo defines Neovim toolchain versions {', '.join(actual_strs)}")
if actual_versions == expected_versions:
    print("\x1b[1;32mNeovim toolchain versions in repo are up to date\x1b[0m")
else:
    print("\x1b[1;31mNeovim toolchain versions in repo need to be updated\x1b[0m")
    sys.exit(1)
