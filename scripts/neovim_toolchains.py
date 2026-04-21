import json
import subprocess
import sys


def main() -> None:
    targets_result = run(
        "./pleasew", "query", "filter", "--include", "neovim_toolchain:*"
    )
    targets = targets_result.splitlines()

    toolchains = []
    for target in targets:
        version = run(
            "./pleasew", "query", "print", target, "--label", "neovim_toolchain:"
        )
        target_name = run("./pleasew", "query", "print", target, "--field", "name")
        toolchains.append(
            {
                "target": target,
                "target_name": target_name,
                "nvim": f"{target}|nvim",
                "version": version,
            }
        )

    print(json.dumps(toolchains))


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
