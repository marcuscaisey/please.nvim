local strings = require 'plenary.strings'
local temptree = require 'please.testutils.temptree'
local TeardownFuncs = require 'please.testutils.teardowns'
local targets = require 'please.targets'

local teardowns = TeardownFuncs:new()

describe('locate_build_target', function()
  it('should return location of a BUILD file in the root of the repo', function()
    local root, teardown = temptree.create_temp_tree {
      '.plzconfig',
      BUILD = strings.dedent [[
        export_file(
            name = "foo",
            src = "foo.txt",
        )]],
      'foo.txt',
    }
    teardowns:add(teardown)
    local label = '//:foo'

    local filepath, _, _, err = targets.locate_build_target(root, label)

    assert.is_nil(err, 'expected no error')
    assert.are.equal(root .. '/BUILD', filepath, 'incorrect filepath')
  end)

  it('should return location of a BUILD file in a child dir of the repo', function()
    local root, teardown = temptree.create_temp_tree {
      '.plzconfig',
      ['foo/'] = {
        BUILD = strings.dedent [[
          export_file(
              name = "foo",
              src = "foo.txt",
          )]],
        'foo.txt',
      },
    }
    teardowns:add(teardown)
    local label = '//foo:foo'

    local filepath, _, _, err = targets.locate_build_target(root, label)

    assert.is_nil(err, 'expected no error')
    assert.are.equal(root .. '/foo/BUILD', filepath, 'incorrect filepath')
  end)

  it('should return location of a BUILD.plz file', function()
    local root, teardown = temptree.create_temp_tree {
      '.plzconfig',
      ['BUILD.plz'] = strings.dedent [[
        export_file(
            name = "foo",
            src = "foo.txt",
        )]],
      'foo.txt',
    }
    teardowns:add(teardown)
    local label = '//:foo'

    local filepath, _, _, err = targets.locate_build_target(root, label)

    assert.is_nil(err, 'expected no error')
    assert.are.equal(root .. '/BUILD.plz', filepath, 'incorrect filepath')
  end)

  it('should return error if pkg path exists but BUILD or BUILD.plz file does not', function()
    local root, teardown = temptree.create_temp_tree {
      '.plzconfig',
      'no_targets/',
    }
    teardowns:add(teardown)
    local label = '//no_targets:target'

    local filepath, line, col, err = targets.locate_build_target(root, label)

    assert.is_nil(filepath, 'expected no filepath')
    assert.is_nil(line, 'expected no line')
    assert.is_nil(col, 'expected no col')
    assert.are.equal('no build file exists for package "no_targets"', err)
  end)

  it('should return error if pkg path does not exist', function()
    local root, teardown = temptree.create_temp_tree {
      '.plzconfig',
    }
    teardowns:add(teardown)
    local label = '//does/not/exist:target'

    local filepath, line, col, err = targets.locate_build_target(root, label)

    assert.is_nil(filepath, 'expected no filepath')
    assert.is_nil(line, 'expected no line')
    assert.is_nil(col, 'expected no col')
    assert.are.equal('no build file exists for package "does/not/exist"', err)
  end)

  it('should return line and col for target at the start of a BUILD file', function()
    local root, teardown = temptree.create_temp_tree {
      '.plzconfig',
      BUILD = strings.dedent [[
        export_file(
            name = "foo",
            src = "foo.txt",
        )]],
      'foo.txt',
    }
    teardowns:add(teardown)
    local label = '//:foo'

    local _, line, col, err = targets.locate_build_target(root, label)

    assert.are.equal(1, line, 'incorrect line')
    assert.are.equal(1, col, 'incorrect line')
    assert.is_nil(err, 'expected no error')
  end)

  it('should return line and col for target in the middle of a BUILD file', function()
    local root, teardown = temptree.create_temp_tree {
      '.plzconfig',
      BUILD = strings.dedent [[
        export_file(
            name = "foo1",
            src = "foo1.txt",
        )

        export_file(
            name = "foo2",
            src = "foo2.txt",
        )]],
      'foo1.txt',
      'foo2.txt',
    }
    teardowns:add(teardown)
    local label = '//:foo2'

    local _, line, col, err = targets.locate_build_target(root, label)

    assert.are.equal(6, line, 'incorrect line')
    assert.are.equal(1, col, 'incorrect line')
    assert.is_nil(err, 'expected no error')
  end)

  it('should return line and col for target which is indented', function()
    local root, teardown = temptree.create_temp_tree {
      '.plzconfig',
      BUILD = strings.dedent [[
          export_file(
            name = "foo",
            src = "foo.txt",
        )]],
      'foo.txt',
    }
    teardowns:add(teardown)
    local label = '//:foo'

    local _, line, col, err = targets.locate_build_target(root, label)

    assert.are.equal(1, line, 'incorrect line')
    assert.are.equal(3, col, 'incorrect line')
    assert.is_nil(err, 'expected no error')
  end)

  it('should return first line and column if target cannot be found in BUILD file', function()
    local root, teardown = temptree.create_temp_tree {
      '.plzconfig',
      BUILD = strings.dedent [[
        export_file(
            name = "not_foo",
            src = "foo.txt",
        )]],
      'foo.txt',
    }
    teardowns:add(teardown)
    local label = '//:foo'

    local _, line, col, err = targets.locate_build_target(root, label)

    assert.are.equal(1, line, 'incorrect line')
    assert.are.equal(1, col, 'incorrect line')
    assert.is_nil(err, 'expected no error')
  end)

  it('should raise error if root is not absolute', function()
    local root = 'repo'
    local label = '//foo:foo'

    assert.has_error(function()
      targets.locate_build_target(root, label)
    end, 'root must be absolute, got "repo"')
  end)

  it('should raise error if label is relative', function()
    local root = '/tmp/root'
    local label = ':foo'

    assert.has_error(function()
      targets.locate_build_target(root, label)
    end, 'label must be in //path/to/pkg:target format, got ":foo"')
  end)

  it('should raise error if label does not have target', function()
    local root = '/tmp/root'
    local label = '//foo'

    assert.has_error(function()
      targets.locate_build_target(root, label)
    end, 'label must be in //path/to/pkg:target format, got "//foo"')
  end)

  it('should raise error if label is not a build label', function()
    local root = '/tmp/root'
    local label = 'foo'

    assert.has_error(function()
      targets.locate_build_target(root, label)
    end, 'label must be in //path/to/pkg:target format, got "foo"')
  end)
end)

teardowns:teardown()
