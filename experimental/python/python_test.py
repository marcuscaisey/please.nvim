import unittest


def decorator(f):
    return f


def decorator_with_params(x):

    def decorator(f):
        return f

    return decorator


class TestCase(unittest.TestCase):

    def test_method_1(self):
        self.fail("oh no")

    def test_method_2(self):
        self.fail("oh no")

    @decorator
    def test_method_with_decorator(self):
        self.fail("oh no")

    @decorator_with_params(2)
    def test_method_with_decorator_with_params(self):
        self.fail("oh no")
