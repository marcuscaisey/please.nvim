local logging = require('_please.logging')
local plz = require('_please.plz')

local M = {}

---@param root string
---@param args string[]
---@return string?
---@return string?
local function plz_query(root, args)
    local ok, obj_or_err = pcall(vim.system, { plz, '--repo_root', root, 'query', unpack(args) })
    if not ok then
        return nil, tostring(obj_or_err)
    end
    local res = obj_or_err:wait()
    if res.code ~= 0 then
        local stderr = vim.trim(res.stderr)
        if not stderr:match('\n') then
            -- If there's only one line, then strip off the prefix since the line is probably an error message. Otherwise, don't
            -- strip the lines since the prefixes (log level and time) might be useful for debugging.
            stderr = stderr:gsub('^%d+:%d+:%d+%.%d+ %u+: ', '')
            stderr = stderr:gsub('^Error: ', '')
        end
        return nil, stderr
    end
    return vim.trim(res.stdout), nil
end

---Wrapper around plz query whatinputs which returns the targets which a file is an input for.
---@param root string: absolute path to repo root
---@param filepath string: absolute path to file
---@return string[]?
---@return string? errmsg
function M.whatinputs(root, filepath)
    logging.log_call('query.whatinputs')

    local output, err = plz_query(root, { 'whatinputs', filepath })
    if err then ---@cast output -?
        return nil, string.format('plz query whatinputs %q: %s', filepath, err)
    end

    local targets = vim.split(output, '\n')
    for i, target in ipairs(targets) do
        local pkg, name = target:match('^//([^:]*):([^/]+)$')
        if pkg and name and name == vim.fs.basename(pkg) then
            targets[i] = target:gsub(':' .. name, '')
        end
    end

    return targets, nil
end

---Wrapper around plz query print which returns the value of the given field for the given target.
---@param root string: absolute path to the repo root
---@param target string: target to query
---@param field string: field name
---@return string?
---@return string? errmsg
function M.print_field(root, target, field)
    logging.log_call('query.print_field')

    local output, err = plz_query(root, { 'print', target, '--field', field })
    if err then ---@cast output -?
        return nil, string.format('plz query print %q --field %q: %s', target, field, err)
    end

    return output
end

---Returns whether the given target should be run in a sandbox.
---@param root string: absolute path to the repo root
---@param target string: target to query
---@return boolean?
---@return string? errmsg
function M.is_target_sandboxed(root, target)
    logging.log_call('query.is_target_sandboxed')

    local test_value, err = M.print_field(root, target, 'test')
    if err then ---@cast test_value -?
        return nil, string.format('checking if %q is sandboxed: %s', target, err)
    end

    local target_is_test = test_value == 'True'
    local sandbox_field = target_is_test and 'test_sandbox' or 'sandbox'

    local sandbox_value, err = M.print_field(root, target, sandbox_field)
    if err then ---@cast sandbox_value -?
        return nil, string.format('checking if %q is sandboxed: %s', target, err)
    end

    return sandbox_value == 'True'
end

---Wrapper around plz query config which returns the value of the given option.
---@param root string: absolute path to the repo root
---@param option string: option name
---@return string[]?
---@return string? errmsg
function M.config(root, option)
    logging.log_call('query.config')

    local output, err = plz_query(root, { 'config', option })
    if err then ---@cast output -?
        return nil, string.format('plz query config %q: %s', option, err)
    end

    return vim.split(output, '\n')
end

---Returns the appropriate GOROOT for a repo.
---@param root string absolute path to the repo root
---@return string?
---@return string? errmsg
function M.goroot(root)
    logging.log_call('query.goroot')

    -- This is the default value set by the go plugin. We set it here because plz query config doesn't return default
    -- values from plugins.
    local gotool = 'go'
    local gotools, err = M.config(root, 'plugin.go.gotool')
    if not err then ---@cast gotools -?
        gotool = gotools[1]
    elseif not err:match('Settable field not defined') then
        return nil, string.format('resolving GOROOT: %s', err)
    end

    local go_cmd ---@type string[]?
    if vim.startswith(gotool, ':') or vim.startswith(gotool, '//') then
        go_cmd = { plz, 'run', gotool }
    elseif vim.startswith(gotool, '/') then
        if vim.fn.executable(gotool) ~= 1 then
            return nil, string.format('resolving GOROOT: plugin.go.gotool %q is not executable', gotool)
        end
        go_cmd = { gotool }
    else
        local build_paths, err = M.config(root, 'build.path')
        if err then ---@cast build_paths -?
            return nil, string.format('resolving GOROOT: %s', err)
        end
        for _, path in ipairs(build_paths) do
            local go = vim.fs.joinpath(path, gotool)
            if vim.fn.executable(go) == 1 then
                go_cmd = { go }
                break
            end
        end
        if not go_cmd then
            return nil,
                string.format(
                    'resolving GOROOT: plugin.go.gotool "%s" not found in build.path "%s"',
                    gotool,
                    table.concat(build_paths, ':')
                )
        end
    end

    local cmd = vim.list_extend(go_cmd, { 'env', 'GOROOT' })
    local ok, obj_or_err = pcall(vim.system, cmd)
    if not ok then
        return nil, string.format('resolving GOROOT: %s: %s', table.concat(cmd, ' '), obj_or_err)
    end
    local res = obj_or_err:wait()
    if res.code ~= 0 then
        return nil, string.format('resolving GOROOT: %s: %s', table.concat(cmd, ' '), vim.trim(res.stderr))
    end
    return vim.trim(res.stdout)
end

return M
