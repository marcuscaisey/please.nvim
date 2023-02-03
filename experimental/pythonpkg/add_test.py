import unittest

from experimental.pythonpkg import add


def decorator(f):
    return f


def decorator_with_params(x):
    def decorator(f):
        return f

    return decorator


class Add(unittest.TestCase):
    def test_equal_numbers(self):
        self.assertEqual(4, add.add(2, 2))

    @decorator
    def test_different_numbers(self):
        self.assertEqual(5, add.add(2, 3))

    @decorator_with_params(2)
    def test_different_numbers_2(self):
        self.assertEqual(5, add.add(2, 3))
