local Path = require 'plenary.path'
local lib = require 'please.lib'

local test_repo_root = Path:new(vim.fn.getcwd(), 'test_repo').filename

describe('locate_build_target', function()
  it('should raise error if root is not absolute', function()
    local root = 'test_repo'
    local label = '//files:file1'

    assert.has_error(function()
      lib.locate_build_target(root, label)
    end, 'root must be absolute, got "test_repo"')
  end)

  it('should raise error if label is relative', function()
    local label = ':file1'

    assert.has_error(function()
      lib.locate_build_target(test_repo_root, label)
    end, 'label must be in //path/to/pkg:target format, got ":file1"')
  end)

  it('should raise error if label does not have target', function()
    local label = '//files'

    assert.has_error(function()
      lib.locate_build_target(test_repo_root, label)
    end, 'label must be in //path/to/pkg:target format, got "//files"')
  end)

  it('should raise error if label is not a build label', function()
    local label = 'foo'

    assert.has_error(function()
      lib.locate_build_target(test_repo_root, label)
    end, 'label must be in //path/to/pkg:target format, got "foo"')
  end)

  it('should return location of a BUILD file in the root of the repo', function()
    local label = '//:hello'

    local filepath, _, _, err = lib.locate_build_target(test_repo_root, label)

    assert.is_nil(err, 'expected no error')
    assert.are.equal(test_repo_root .. '/BUILD', filepath, 'incorrect filepath')
  end)

  it('should return location of a BUILD file in a child dir of the repo', function()
    local label = '//files:file1'

    local filepath, _, _, err = lib.locate_build_target(test_repo_root, label)

    assert.is_nil(err, 'expected no error')
    assert.are.equal(test_repo_root .. '/files/BUILD', filepath, 'incorrect filepath')
  end)

  it('should return location of a BUILD file in a grandchild dir of the repo', function()
    local label = '//third_party/go:toolchain'

    local filepath, _, _, err = lib.locate_build_target(test_repo_root, label)

    assert.is_nil(err, 'expected no error')
    assert.are.equal(test_repo_root .. '/third_party/go/BUILD', filepath, 'incorrect filepath')
  end)

  it('should return location of a BUILD.plz file', function()
    local label = '//foo/bar:bar'

    local filepath, _, _, err = lib.locate_build_target(test_repo_root, label)

    assert.is_nil(err, 'expected no error')
    assert.are.equal(test_repo_root .. '/foo/bar/BUILD.plz', filepath, 'incorrect filepath')
  end)

  it('should return error if pkg path exists but BUILD or BUILD.plz file does not', function()
    local label = '//no_targets:target'

    -- TODO: should we return nil for line and col as well?
    local filepath, line, col, err = lib.locate_build_target(test_repo_root, label)

    assert.is_nil(filepath, 'expected no filepath')
    assert.is_nil(line, 'expected no line')
    assert.is_nil(col, 'expected no col')
    assert.are.equal('no build file exists for package "no_targets"', err)
  end)

  it('should return error if pkg path does not exist', function()
    local label = '//does/not/exist:target'

    local filepath, line, col, err = lib.locate_build_target(test_repo_root, label)

    assert.is_nil(filepath, 'expected no filepath')
    assert.is_nil(line, 'expected no line')
    assert.is_nil(col, 'expected no col')
    -- TODO: should this be a different error message to make the two not exists cases distinct?
    assert.are.equal('no build file exists for package "does/not/exist"', err)
  end)

  it('should return line and col for target at the start of a BUILD file', function()
    local label = '//files:file1'

    local _, line, col, err = lib.locate_build_target(test_repo_root, label)

    assert.are.equal(1, line, 'incorrect line')
    assert.are.equal(1, col, 'incorrect line')
    assert.is_nil(err, 'expected no error')
  end)

  it('should return line and col for target in the middle of a BUILD file', function()
    local label = '//files:file2'

    local _, line, col, err = lib.locate_build_target(test_repo_root, label)

    -- TODO: instead of matching on line number, we should read the line starting from (line, col) and see if its
    -- correct, that would be resilient against moving the target up or down by a line or something like that
    assert.are.equal(7, line, 'incorrect line')
    assert.are.equal(1, col, 'incorrect line')
    assert.is_nil(err, 'expected no error')
  end)

  it('should return line and col for target which is indented', function()
    local label = '//files:all_files'

    local _, line, col, err = lib.locate_build_target(test_repo_root, label)

    assert.are.equal(14, line, 'incorrect line')
    assert.are.equal(5, col, 'incorrect line')
    assert.is_nil(err, 'expected no error')
  end)

  it('should return first line and column if target cannot be found in BUILD file', function()
    local label = '//files:does_not_exist'

    local _, line, col, err = lib.locate_build_target(test_repo_root, label)

    assert.are.equal(1, line, 'incorrect line')
    assert.are.equal(1, col, 'incorrect line')
    assert.is_nil(err, 'expected no error')
  end)
end)
