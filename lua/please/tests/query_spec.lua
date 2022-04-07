local strings = require 'plenary.strings'
local temptree = require 'please.tests.utils.temptree'
local TeardownFuncs = require 'please.tests.utils.teardowns'
local query = require 'please.query'

local teardowns = TeardownFuncs:new()

describe('reporoot', function()
  it('should raise error when path is not absolute', function()
    local path = 'not/absolute/path.txt'

    assert.has_error(function()
      query.reporoot(path)
    end, 'path must be absolute, got not/absolute/path.txt')
  end)

  it('should return root when path is a directory inside a plz repo', function()
    local temp_root, teardown = temptree.create_temp_tree {
      '.plzconfig',
      'foo/',
    }
    teardowns:add(teardown)
    local path = temp_root .. '/foo'

    local root, err = query.reporoot(path)

    assert.is_nil(err, 'expected no error')
    assert.are.equal(temp_root, root, 'incorrect root')
  end)

  it('should return root when path is a file inside a plz repo', function()
    local temp_root, teardown = temptree.create_temp_tree {
      '.plzconfig',
      ['foo/'] = {
        'foo.go',
      },
    }
    teardowns:add(teardown)
    local path = temp_root .. '/foo/foo.go'

    local root, err = query.reporoot(path)

    assert.is_nil(err, 'expected no error')
    assert.are.equal(temp_root, root, 'incorrect root')
  end)

  it('should return error when path is outside of a plz repo', function()
    local temp_root, teardown = temptree.create_temp_tree {
      ['repo/'] = {
        '.plzconfig',
      },
    }
    teardowns:add(teardown)

    local root, err = query.reporoot(temp_root)

    assert.is_nil(root, 'expected no root')
    assert.is_not_nil(err, 'expected error')
    assert.are.equal('string', type(err), 'expected error to be string')
  end)
end)

describe('whatinputs', function()
  local teardowns = TeardownFuncs:new()
  after_each(function()
    teardowns:teardown()
  end)

  it('should return target when filepath is relative', function()
    local repo_root, teardown = temptree.create_temp_tree {
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
    local filepath = 'foo/foo.txt'

    local labels, err = query.whatinputs(repo_root, filepath)

    assert.is_nil(err, 'expected no error')
    assert.are.same({ '//foo:foo' }, labels, 'incorrect labels')
  end)

  it('should return target when filepath is absolute', function()
    local repo_root, teardown = temptree.create_temp_tree {
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
    local filepath = repo_root .. '/foo/foo.txt'

    local labels, err = query.whatinputs(repo_root, filepath)

    assert.is_nil(err, 'expected no error')
    assert.are.same({ '//foo:foo' }, labels, 'incorrect labels')
  end)

  it('should return the labels of multiple targets if they exist', function()
    local repo_root, teardown = temptree.create_temp_tree {
      '.plzconfig',
      ['foo/'] = {
        BUILD = strings.dedent [[
          export_file(
              name = "foo1",
              src = "foo.txt",
          )
          export_file(
              name = "foo2",
              src = "foo.txt",
          )]],
        'foo.txt',
      },
    }
    teardowns:add(teardown)
    local filepath = 'foo/foo.txt'

    local labels, err = query.whatinputs(repo_root, filepath)

    assert.is_nil(err, 'expected no error')
    assert.are.same({ '//foo:foo1', '//foo:foo2' }, labels, 'incorrect labels')
  end)

  it('should return error if no targets exist for a file which is not in a package', function()
    local repo_root, teardown = temptree.create_temp_tree {
      '.plzconfig',
      ['foo/'] = {
        'not_used.txt',
      },
    }
    teardowns:add(teardown)
    local filepath = 'foo/not_used.txt'

    local labels, err = query.whatinputs(repo_root, filepath)

    assert.is_nil(labels, 'expected no labels')
    assert.is_not_nil(err, 'expected error')
    -- TODO: should add test helpers for these checks
    assert.are.equal('string', type(err), 'expected error to be string')
    assert.is_truthy(
      err:match "doesn't exist",
      string.format([[expected error to contain "doesn't exist", got %s]], err)
    )
  end)

  it('should return error if no targets exist for a file which is in a package', function()
    local repo_root, teardown = temptree.create_temp_tree {
      '.plzconfig',
      ['foo/'] = {
        'BUILD',
        'not_used.txt',
      },
    }
    teardowns:add(teardown)
    local filepath = 'foo/not_used.txt'

    local labels, err = query.whatinputs(repo_root, filepath)

    assert.is_nil(labels, 'expected no labels')
    assert.is_not_nil(err, 'expected error')
    assert.are.equal('string', type(err), 'expected error to be string')
    assert.is_truthy(err:match 'not a source', string.format('expected error to contain "not a source", got %s', err))
  end)

  it('should raise error if filepath is an absolute directory', function()
    local repo_root, teardown = temptree.create_temp_tree {
      'BUILD',
      'foo/',
    }
    teardowns:add(teardown)
    local filepath = repo_root .. '/foo'

    assert.has_error(function()
      query.whatinputs(repo_root, filepath)
    end, 'filepath must point to a file, got ' .. filepath)
  end)

  it('should raise error if filepath is a relative directory', function()
    local repo_root, teardown = temptree.create_temp_tree {
      'BUILD',
      'foo/',
    }
    teardowns:add(teardown)
    local filepath = 'foo'

    assert.has_error(function()
      query.whatinputs(repo_root, filepath)
    end, 'filepath must point to a file, got foo')
  end)

  it('should raise error is root is not absolute', function()
    local root = 'test_repo'
    local filepath = 'foo/foo.txt'

    assert.has_error(function()
      query.whatinputs(root, filepath)
    end, 'root must be absolute, got test_repo')
  end)
end)

teardowns:teardown()
