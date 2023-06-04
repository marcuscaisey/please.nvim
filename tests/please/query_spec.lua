local temptree = require('tests.utils.temptree')
local query = require('please.query')

describe('whatinputs', function()
  it('should return target when filepath is relative', function()
    local repo_root, teardown_tree = temptree.create({
      '.plzconfig',
      ['foo/'] = {
        BUILD = [[
          export_file(
              name = "foo",
              src = "foo.txt",
          )]],
        'foo.txt',
      },
    })
    local filepath = 'foo/foo.txt'

    local labels, err = query.whatinputs(repo_root, filepath)

    assert.is_nil(err, 'expected no error')
    assert.are.same({ '//foo:foo' }, labels, 'incorrect labels')

    teardown_tree()
  end)

  it('should return target when filepath is absolute', function()
    local repo_root, teardown_tree = temptree.create({
      '.plzconfig',
      ['foo/'] = {
        BUILD = [[
          export_file(
              name = "foo",
              src = "foo.txt",
          )]],
        'foo.txt',
      },
    })
    local filepath = repo_root .. '/foo/foo.txt'

    local labels, err = query.whatinputs(repo_root, filepath)

    assert.is_nil(err, 'expected no error')
    assert.are.same({ '//foo:foo' }, labels, 'incorrect labels')

    teardown_tree()
  end)

  it('should return the labels of multiple targets if they exist', function()
    local repo_root, teardown_tree = temptree.create({
      '.plzconfig',
      ['foo/'] = {
        BUILD = [[
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
    })
    local filepath = 'foo/foo.txt'

    local labels, err = query.whatinputs(repo_root, filepath)

    assert.is_nil(err, 'expected no error')
    assert.are.same({ '//foo:foo1', '//foo:foo2' }, labels, 'incorrect labels')

    teardown_tree()
  end)

  it('should return error if no targets exist for a file which is not in a package', function()
    local repo_root, teardown_tree = temptree.create({
      '.plzconfig',
      ['foo/'] = {
        'not_used.txt',
      },
    })
    local filepath = 'foo/not_used.txt'

    local labels, err = query.whatinputs(repo_root, filepath)

    assert.is_nil(labels, 'expected no labels')
    assert.is_not_nil(err, 'expected error')
    -- TODO: should add test helpers for these checks
    assert.are.equal('string', type(err), 'expected error to be string')
    assert.is_truthy(
      ---@diagnostic disable-next-line: need-check-nil
      err:match("doesn't exist"),
      string.format([[expected error to contain "doesn't exist", got %s]], err)
    )

    teardown_tree()
  end)

  it('should return error if no targets exist for a file which is in a package', function()
    local repo_root, teardown_tree = temptree.create({
      '.plzconfig',
      ['foo/'] = {
        'BUILD',
        'not_used.txt',
      },
    })
    local filepath = 'foo/not_used.txt'

    local labels, err = query.whatinputs(repo_root, filepath)

    assert.is_nil(labels, 'expected no labels')
    assert.is_not_nil(err, 'expected error')
    assert.are.equal('string', type(err), 'expected error to be string')
    ---@diagnostic disable-next-line: need-check-nil
    assert.is_truthy(err:match('not a source'), string.format('expected error to contain "not a source", got %s', err))

    teardown_tree()
  end)
end)

describe('is_target_sandboxed', function()
  local run_tests = function(opts)
    local test_cases = {
      { rule_sandbox = nil, config_sandbox = nil, expected = false },
      { rule_sandbox = nil, config_sandbox = false, expected = false },
      { rule_sandbox = nil, config_sandbox = true, expected = true },
      { rule_sandbox = false, config_sandbox = nil, expected = false },
      { rule_sandbox = false, config_sandbox = false, expected = false },
      { rule_sandbox = false, config_sandbox = true, expected = false },
      { rule_sandbox = true, config_sandbox = nil, expected = true },
      { rule_sandbox = true, config_sandbox = false, expected = true },
      { rule_sandbox = true, config_sandbox = true, expected = true },
    }

    for _, tc in ipairs(test_cases) do
      local test_name = table.concat({
        'returns',
        tostring(tc.expected),
        string.format('when %s', opts.rule_name),
        (tc.rule_sandbox == nil and "doesn't have sandbox set")
          or (tc.rule_sandbox and 'has sandbox=True')
          or 'has sandbox=False',
        'and config',
        (tc.config_sandbox == nil and string.format("doesn't have sandbox.%s set", opts.sandbox_config_key))
          or (tc.config_sandbox and string.format('has sandbox.%s=True', opts.sandbox_config_key))
          or string.format('has sandbox.%s=False', opts.sandbox_config_key),
      }, ' ')

      it(test_name, function()
        local tree = {}
        if tc.rule_sandbox ~= nil then
          tree.BUILD = ([[
            %s(
                name = 'rule',
                %s = 'echo hello',
                sandbox = %s,
            )
          ]]):format(opts.rule_name, opts.cmd_field_name, tc.rule_sandbox and 'True' or 'False')
        else
          tree.BUILD = ([[
            %s(
                name = 'rule',
                %s = 'echo hello',
            )
          ]]):format(opts.rule_name, opts.cmd_field_name)
        end

        if tc.config_sandbox ~= nil then
          tree['.plzconfig'] = ([[
            [sandbox]
            %s = %s
          ]]):format(opts.sandbox_config_key, tc.config_sandbox and 'True' or 'False')
        else
          tree['.plzconfig'] = nil
        end

        local root = temptree.create(tree)

        local actual, err = query.is_target_sandboxed(root, '//:rule')

        assert.is_nil(err, 'expected no error')
        local msg = table.concat({ 'expected target to', tc.expected and 'be sandboxed ' or 'not be sandboxed' }, ' ')
        assert.are.equal(tc.expected, actual, msg)
      end)
    end
  end

  describe('for build target', function()
    run_tests({
      rule_name = 'genrule',
      cmd_field_name = 'cmd',
      sandbox_config_key = 'build',
    })
  end)

  describe('for test target', function()
    run_tests({
      rule_name = 'gentest',
      cmd_field_name = 'test_cmd',
      sandbox_config_key = 'test',
    })
  end)
end)
