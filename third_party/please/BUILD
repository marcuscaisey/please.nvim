VERSION = CONFIG.PLZ_VERSION

remote_file(
    name = "plz",
    out = "plz",
    binary = True,
    url = f"https://github.com/thought-machine/please/releases/download/v{VERSION}/please_{VERSION}_{CONFIG.HOSTOS}_{CONFIG.HOSTARCH}",
    visibility = ["PUBLIC"],
)
