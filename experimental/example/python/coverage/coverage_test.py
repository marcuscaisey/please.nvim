import unittest

from experimental.example.python.coverage import maths, greetings


class CoverageTest(unittest.TestCase):
    def test_add(self):
        self.assertEqual(maths.add(2, 3), 5)

    def test_classify_number(self):
        self.assertEqual(maths.classify_number(0), "zero")
        self.assertEqual(maths.classify_number(4), "positive even")

    def test_hello(self):
        self.assertEqual(greetings.hello("Please"), "Hello, Please.")
