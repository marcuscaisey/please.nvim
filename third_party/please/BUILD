VERSION = "16.28.0"

remote_file(
    name = "plz",
    url = f"https://github.com/thought-machine/please/releases/download/v{VERSION}/please_{VERSION}_{CONFIG.OS}_{CONFIG.ARCH}",
    hashes = [
        "a6253fa89b036532e863d9733e210807c882997993ca779c3f570a44e85083db", # darwin_arm64
        "6c8a51abf87a8504fdcc3bd61b1a1027318c7ed90ef4b35711f8896ea044733d", # darwin_amd64
        "3afeb61bf64e973432098e57081c8588080ccd67ad2d2c7314d8853e616811e6", # linux_amd64
    ],
    out = "plz",
    binary = True,
    visibility = ["PUBLIC"],
)
