import collections
import re
import subprocess
import sys
from typing import Any

import requests


def main() -> None:
    expected_versions = latest_stable_neovim_versions()
    actual_versions = repo_neovim_toolchain_versions()
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


def latest_stable_neovim_versions() -> list[str]:
    releases = list_releases()
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
    latest_versions = []
    for major_minor, latest_patch in sorted(latest_patches_by_major_minor.items())[-2:]:
        latest_versions.append((*major_minor, latest_patch))
    if (min_expected_version := latest_versions[0])[2] != 0:
        min_supported_version = (min_expected_version[0], min_expected_version[1], 0)
        latest_versions.insert(0, min_supported_version)
    return latest_versions


def list_releases() -> list[Any]:
    releases = []
    next_page_url = "https://api.github.com/repos/neovim/neovim/releases?page_size=100"
    while True:
        next_page = requests.get(
            next_page_url,
            headers={
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2026-03-10",
            },
        )
        next_page.raise_for_status()

        releases.extend(next_page.json())

        link_header = next_page.headers.get("link", "")
        if not (match := re.match(r'(?i)(?<=<)([\S]*)(?=>; rel="next")', link_header)):
            break
        next_page_url = match.group(1)
    return releases


def repo_neovim_toolchain_versions() -> list[str]:
    targets_result = run(
        "./pleasew", "query", "filter", "--include", "neovim_toolchain:*"
    )
    targets = targets_result.splitlines()
    repo_versions = []
    for target in targets:
        version = run(
            "./pleasew", "query", "print", target, "--label", "neovim_toolchain:"
        )
        major, minor, patch = (int(n) for n in version.split("."))
        repo_versions.append((major, minor, patch))
    repo_versions.sort()
    return repo_versions


def run(*args: str) -> str:
    try:
        result = subprocess.run([*args], capture_output=True, check=True, text=True)
    except subprocess.CalledProcessError as e:
        msg = f"'{' '.join(args)}' exited with code {e.returncode}\nstdout: {e.stdout}\nstderr: {e.stderr}"
        print(msg)
        sys.exit(e.returncode)
    return result.stdout.strip()


if __name__ == "__main__":
    main()
