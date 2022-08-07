from third_party.python import requests

if __name__ == "__main__":
    resp = requests.get("https://google.com")
    if resp.ok:
        print("Google is up")
    else:
        print("Google is down")
