import random


def count(n: int):
    print(f"counting to {n}...")
    for i in range(1, n + 1):
        print(i)


if __name__ == "__main__":
    n = random.randint(1, 10)
    count(n)
