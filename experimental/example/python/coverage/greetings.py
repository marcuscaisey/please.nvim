def hello(name: str, excited: bool = False) -> str:
    message = f"Hello, {name}"
    if excited:
        return message + "!"
    return message + "."


def farewell(name: str) -> str:
    return f"Goodbye, {name}."
