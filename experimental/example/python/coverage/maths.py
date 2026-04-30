def add(left: int, right: int) -> int:
    return left + right


def classify_number(value: int) -> str:
    if value < 0:
        return "negative"
    if value == 0:
        return "zero"
    if value % 2 == 0:
        return "positive even"
    return "positive odd"


def factorial(value: int) -> int:
    if value < 0:
        raise ValueError("factorial is undefined for negative numbers")

    result = 1
    for number in range(2, value + 1):
        result *= number

    return result
