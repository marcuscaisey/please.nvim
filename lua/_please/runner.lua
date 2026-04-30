local logging = require('_please.logging')
local plz = require('_please.plz')

local M = {
    ---@type _please.runner.Runner?
    current = nil,
}

---@alias _please.runner.OnExitHandler fun(code:integer, runner:_please.runner.Runner)

---A Please command runner that displays its output in a floating window.
---@class _please.runner.Runner
---@field package _bufnr integer
---@field package _winid integer
---@field package _augroup integer
---@field package _stopped boolean
---@field package _job_id integer
---@field package _job_exited boolean
---@field package _on_exit _please.runner.OnExitHandler?
---@field package _minimised boolean
---@field package _prev_cursor_position integer[]
local Runner = {}
Runner.__index = Runner
M.Runner = Runner

local ANSI_REPLACEMENTS = {
    DEFAULT = '\x1b[39m',
    RESET = '\x1b[0m',
    ITALIC = '\x1b[3m',
    BLACK = '\x1b[30m',
    RED = '\x1b[31m',
    GREEN = '\x1b[32m',
    YELLOW = '\x1b[33m',
    BLUE = '\x1b[34m',
    MAGENTA = '\x1b[35m',
    CYAN = '\x1b[36m',
    WHITE = '\x1b[37m',
}

---Wraps string.format and replaces ${STYLE} strings with their respective ANSI escape sequences.
---For example ${YELLOW} is replaced by \x1b[33m.
---@param s string
---@param ... any
---@return string
local function format(s, ...)
    s = s:gsub('${(%u+)}', ANSI_REPLACEMENTS)
    return string.format(s, ...)
end

---@param bufnr integer
---@param augroup integer
---@return integer winid
local function open_win(bufnr, augroup)
    local width_pct = 0.9
    local height_pct = 0.9
    local padding_top_bottom = 2
    local padding_left_right = 4

    local bg_bufnr = vim.api.nvim_create_buf(
        false, -- listed
        true -- scratch
    )
    vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = bg_bufnr })
    local bg_width = math.floor(width_pct * vim.o.columns)
    local bg_height = math.floor(height_pct * vim.o.lines)
    local bg_config = {
        relative = 'editor',
        width = bg_width,
        height = bg_height,
        row = math.floor((vim.o.lines - bg_height) / 2),
        col = math.floor((vim.o.columns - bg_width) / 2),
        focusable = false,
        style = 'minimal',
        noautocmd = true,
    }
    local bg_winid = vim.api.nvim_open_win(bg_bufnr, false, bg_config)

    local fg_width = bg_width - 2 * padding_left_right
    local fg_height = bg_height - 2 * padding_top_bottom
    local fg_winid = vim.api.nvim_open_win(bufnr, true, {
        relative = 'editor',
        width = fg_width,
        height = fg_height,
        row = math.floor((vim.o.lines - fg_height) / 2),
        col = math.floor((vim.o.columns - fg_width) / 2),
        focusable = true,
        style = 'minimal',
        noautocmd = true,
        border = 'none',
    })

    local msg = [[ Press q to quit   Press m to minimise   Execute :Please maximise_popup to maximise ]]
    local indent = padding_left_right + math.floor((fg_width - #msg) / 2)
    vim.api.nvim_buf_set_lines(bg_bufnr, 0, 1, false, { string.rep(' ', indent) .. msg })

    local namespace = vim.api.nvim_create_namespace('please.runner')
    local bg_higroup = 'CursorLine'
    vim.hl.range(bg_bufnr, namespace, bg_higroup, { 0, indent }, { 0, indent + 17 }) -- Press q to quit
    vim.hl.range(bg_bufnr, namespace, bg_higroup, { 0, indent + 18 }, { 0, indent + 39 }) -- Press m to minimise
    vim.hl.range(bg_bufnr, namespace, bg_higroup, { 0, indent + 40 }, { 0, indent + 84 }) -- Execute :Please maximise_popup to maximise
    local command_higroup = '@markup.raw'
    vim.hl.range(bg_bufnr, namespace, command_higroup, { 0, indent + 7 }, { 0, indent + 8 }) -- q
    vim.hl.range(bg_bufnr, namespace, command_higroup, { 0, indent + 25 }, { 0, indent + 26 }) -- m
    vim.hl.range(bg_bufnr, namespace, command_higroup, { 0, indent + 49 }, { 0, indent + 71 }) -- :Please maximise_popup

    vim.api.nvim_create_autocmd('WinLeave', {
        desc = 'Close the background window when the foreground window is left',
        group = augroup,
        buffer = bufnr,
        once = true,
        callback = function()
            vim.api.nvim_win_close(bg_winid, false)
        end,
    })

    return fg_winid
end

local function move_cursor_to_last_line()
    -- Move the cursor to the last line so that the output automatically scrolls
    vim.api.nvim_feedkeys('G', 'nx', false)
end

---@class _please.runner.RunnerOpts
---@field on_exit _please.runner.OnExitHandler?

---Runs a command and displays it in a floating window.
---@param root string
---@param args string[]
---@param opts _please.runner.RunnerOpts?
---@return _please.runner.Runner
function Runner.start(root, args, opts)
    logging.log_call('runner.Runner.start')

    if M.current then
        M.current:_destroy()
    end

    local runner = setmetatable({}, Runner)

    local bufnr = vim.api.nvim_create_buf(
        false, -- listed
        true -- scratch
    )

    local augroup = vim.api.nvim_create_augroup('please.runner_' .. bufnr, {})

    vim.cmd.stopinsert() -- Make sure that we're not in insert or terminal mode otherwise the cursor gets stuck.
    local winid = open_win(bufnr, augroup)
    local term_chan_id = vim.api.nvim_open_term(bufnr, {})

    ---@param data string
    local print_to_term = vim.schedule_wrap(function(data)
        vim.api.nvim_chan_send(term_chan_id, data)
    end)

    local cmd_string = table.concat({ plz, unpack(args) }, ' ')
    print_to_term(format('${BLUE}%s\n\n', cmd_string))

    local job_id = vim.fn.jobstart({ plz, unpack({ '--repo_root', root, unpack(args) }) }, {
        pty = true,
        width = vim.api.nvim_win_get_width(winid),
        height = vim.api.nvim_win_get_height(winid),
        ---@param data string[]
        on_stdout = function(_, data, _)
            local eof = vim.deep_equal(data, { '' })
            if eof then
                return
            end
            print_to_term(table.concat(data, '\n'))
        end,
        ---@param code integer
        on_exit = function(_, code, _)
            runner._job_exited = true
            if runner._minimised and not runner._stopped then
                logging.info('%s exited with code %d', cmd_string, code)
            end
            local success = code == 0
            local colour
            if success then
                colour = '${GREEN}'
            else
                colour = '${RED}'
            end
            print_to_term(format('\n' .. colour .. 'Exited with code %d', code))
            if runner._on_exit then
                vim.schedule(function()
                    runner._on_exit(code, runner)
                end)
            end
        end,
    })

    move_cursor_to_last_line()

    -- It's easy to get stuck in terminal mode without any indication that you need to press <c-\><c-n> to get out
    vim.api.nvim_create_autocmd('TermEnter', {
        desc = 'Exit terminal mode',
        group = augroup,
        buffer = bufnr,
        callback = function()
            vim.cmd.stopinsert()
        end,
    })

    vim.keymap.set('n', 'q', function()
        runner:_stop()
        runner:minimise()
    end, { buffer = bufnr })

    vim.keymap.set('n', 'm', function()
        runner:minimise()
    end, { buffer = bufnr })

    vim.api.nvim_create_autocmd('WinLeave', {
        desc = 'Close the foreground window, set minimised flag, and save cursor position',
        group = augroup,
        buffer = bufnr,
        callback = function()
            runner._minimised = true
            runner._prev_cursor_position = vim.api.nvim_win_get_cursor(runner._winid)
            vim.api.nvim_win_close(runner._winid, false)
        end,
    })

    opts = opts or {}
    runner._bufnr = bufnr
    runner._winid = winid
    runner._augroup = augroup
    runner._stopped = false
    runner._job_id = job_id
    runner._job_exited = false
    runner._on_exit = opts.on_exit
    runner._minimised = false
    runner._prev_cursor_position = { 1, 0 }

    M.current = runner

    return runner
end

---Minimises the floating window.
function Runner:minimise()
    if not self._winid then
        error('minimise called on Runner that has not been started')
    end
    if self._minimised then
        return
    end
    vim.api.nvim_win_close(self._winid, false)
end

---Maximises the floating window.
function Runner:maximise()
    if not self._bufnr then
        error('maximise called on Runner that has not been started')
    end
    if not self._minimised then
        return
    end
    self._minimised = false
    self._winid = open_win(self._bufnr, self._augroup)
    if self._job_exited then
        vim.api.nvim_win_set_cursor(0, self._prev_cursor_position)
    else
        move_cursor_to_last_line()
    end
end

---@package
---Stops the command, closes the floating window, and cleans up created autocmds.
function Runner:_destroy()
    self:_stop()
    self:minimise()
    vim.api.nvim_del_augroup_by_id(self._augroup)
end

---@package
---Stops the command.
function Runner:_stop()
    if not self._job_id then
        error('stop called on Runner that has not been started')
    end
    self._stopped = true
    vim.fn.jobstop(self._job_id)
end

return M
