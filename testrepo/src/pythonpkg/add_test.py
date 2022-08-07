import unittest

from pythonpkg import add


class TestAdd(unittest.TestCase):
    def test_equal_numbers(self):
        self.assertEqual(4, add.add(2, 2))

    def test_different_numbers(self):
        self.assertEqual(5, add.add(2, 3))
