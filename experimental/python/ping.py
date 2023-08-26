import os
import sys

from third_party.python import requests

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Provide a URL to ping")
        os.exit(1)
    url = sys.argv[1]
    resp = requests.get(url)
    status = "up" if resp.ok else "down"
    print(f"{url} is {status}")
