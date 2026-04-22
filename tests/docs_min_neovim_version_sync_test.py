import re
import unittest

PLUGIN_SCRIPT_PATH = "plugin/please.lua"


class DocsMinNeovimVersionSyncTest(unittest.TestCase):
    def test_health_min_neovim_version_in_sync_with_plugin_script(self):
        health_path = "lua/please/health.lua"
        expected = self.read_lua_file_min_nvim_version(PLUGIN_SCRIPT_PATH)
        actual = self.read_lua_file_min_nvim_version(health_path)
        self.assertEqual(
            actual,
            expected,
            f"Minimum Neovim version defined in {health_path} out of sync with {PLUGIN_SCRIPT_PATH}",
        )

    def test_README_min_neovim_version_in_sync_with_plugin_script(self):
        readme_path = "README.md"
        expected = self.read_lua_file_min_nvim_version(PLUGIN_SCRIPT_PATH)
        actual = self.read_text_file_min_neovim_version(readme_path)
        self.assertEqual(
            actual,
            expected,
            f"Minimum Neovim version defined in {readme_path} out of sync with {PLUGIN_SCRIPT_PATH}",
        )

    def test_help_min_neovim_version_in_sync_with_plugin_script(self):
        help_path = "doc/please.txt"
        expected = self.read_lua_file_min_nvim_version(PLUGIN_SCRIPT_PATH)
        actual = self.read_text_file_min_neovim_version(help_path)
        self.assertEqual(
            actual,
            expected,
            f"Minimum Neovim version defined in {help_path} out of sync with {PLUGIN_SCRIPT_PATH}",
        )

    def read_lua_file_min_nvim_version(self, path: str) -> str:
        with open(path) as f:
            text = f.read()
        pattern = r"(?m)^\s*local min_nvim_version = '(\d+\.\d+\.\d+)'$"
        if not (match := re.search(pattern, text)):
            self.fail(
                f"Lua file {path} doesn't contain 'local min_nvim_version = ...' line"
            )
        return match.group(1)

    def read_text_file_min_neovim_version(self, path: str) -> str:
        with open(path) as f:
            text = f.read()
        pattern = r"(?m)^\s*(?:-|•) Neovim >= (\d+\.\d+\.\d+)$"
        if not (match := re.search(pattern, text)):
            self.fail(
                f"Lua file {path} doesn't contain '- Neovim >= ...' or '• Neovim >= ...' line"
            )
        return match.group(1)
