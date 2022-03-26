local Path = require 'plenary.path'
local query = require 'please.query'

local test_repo_root = Path:new(vim.fn.getcwd(), 'test_repo').filename

describe('reporoot', function()
  it('should raise error when path is not absolute', function()
    local path = 'stylua.toml'

    assert.has_error(function()
      query.reporoot(path)
    end, 'path must be absolute, got stylua.toml')
  end)

  it('should return root when path is a directory inside a plz repo', function()
    local path = test_repo_root .. '/foo'

    local root, err = query.reporoot(path)

    assert.is_nil(err, 'expected no error')
    assert.are.equal(test_repo_root, root, 'incorrect root')
  end)

  it('should return root when path is a file inside a plz repo', function()
    local path = test_repo_root .. '/foo/foo.go'

    local root, err = query.reporoot(path)

    assert.is_nil(err, 'expected no error')
    assert.are.equal(test_repo_root, root, 'incorrect root')
  end)

  it('should return error when path is outside of a plz repo', function()
    local path = Path:new('stylua.toml'):absolute()

    local root, err = query.reporoot(path)

    assert.is_nil(root, 'expected no root')
    assert.is_not_nil(err, 'expected error')
    assert.are.equal('string', type(err), 'expected error to be string')
  end)
end)

describe('whatinputs', function()
  it('should return target when filepath is relative', function()
    local filepath = 'foo/foo.go'

    local targets, err = query.whatinputs(test_repo_root, filepath)

    assert.is_nil(err, 'expected no error')
    assert.are.same({ '//foo:foo' }, targets, 'incorrect targets')
  end)

  it('should return target when filepath is absolute', function()
    local filepath = test_repo_root .. '/foo/foo.go'

    local targets, err = query.whatinputs(test_repo_root, filepath)

    assert.is_nil(err, 'expected no error')
    assert.are.same({ '//foo:foo' }, targets, 'incorrect targets')
  end)

  it('should return multiple targets if they exist', function()
    local filepath = 'files/file1.txt'

    local targets, err = query.whatinputs(test_repo_root, filepath)

    assert.is_nil(err, 'expected no error')
    assert.are.same({ '//files:all_files', '//files:file1' }, targets, 'incorrect targets')
  end)

  it('should return error if no targets exist for a file', function()
    local filepath = 'files/not_used.txt'

    local targets, err = query.whatinputs(test_repo_root, filepath)

    assert.is_nil(targets, 'expected no targets')
    assert.is_not_nil(err, 'expected error')
    assert.are.equal('string', type(err), 'expected error to be string')
    assert.is_truthy(err:match 'not a source', 'expected error to contain "not a source"')
  end)

  it('should raise error if filepath is an absolute directory', function()
    local filepath = test_repo_root .. '/foo'

    assert.has_error(function()
      query.whatinputs(test_repo_root, filepath)
    end, 'filepath must point to a file, got ' .. filepath)
  end)

  it('should raise error if filepath is a relative directory', function()
    local filepath = 'foo'

    assert.has_error(function()
      query.whatinputs(test_repo_root, filepath)
    end, 'filepath must point to a file, got foo')
  end)

  it('should raise error is root is not absolute', function()
    local root = 'test_repo'
    local filepath = 'foo/foo.go'

    assert.has_error(function()
      query.whatinputs(root, filepath)
    end, 'root must be absolute, got test_repo')
  end)
end)
