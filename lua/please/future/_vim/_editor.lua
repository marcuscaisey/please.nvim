local M = {}

-- TODO(lewis6991): document that the signature is system({cmd}, [{opts},] {on_exit})
--- Runs a system command or throws an error if {cmd} cannot be run.
---
--- Examples:
---
--- ```lua
--- local on_exit = function(obj)
---   print(obj.code)
---   print(obj.signal)
---   print(obj.stdout)
---   print(obj.stderr)
--- end
---
--- -- Runs asynchronously:
--- vim.system({'echo', 'hello'}, { text = true }, on_exit)
---
--- -- Runs synchronously:
--- local obj = vim.system({'echo', 'hello'}, { text = true }):wait()
--- -- { code = 0, signal = 0, stdout = 'hello', stderr = '' }
---
--- ```
---
--- See |uv.spawn()| for more details. Note: unlike |uv.spawn()|, vim.system
--- throws an error if {cmd} cannot be run.
---
--- @param cmd (string[]) Command to execute
--- @param opts vim.SystemOpts? Options:
---   - cwd: (string) Set the current working directory for the sub-process.
---   - env: table<string,string> Set environment variables for the new process. Inherits the
---     current environment with `NVIM` set to |v:servername|.
---   - clear_env: (boolean) `env` defines the job environment exactly, instead of merging current
---     environment.
---   - stdin: (string|string[]|boolean) If `true`, then a pipe to stdin is opened and can be written
---     to via the `write()` method to SystemObj. If string or string[] then will be written to stdin
---     and closed. Defaults to `false`.
---   - stdout: (boolean|function)
---     Handle output from stdout. When passed as a function must have the signature `fun(err: string, data: string)`.
---     Defaults to `true`
---   - stderr: (boolean|function)
---     Handle output from stderr. When passed as a function must have the signature `fun(err: string, data: string)`.
---     Defaults to `true`.
---   - text: (boolean) Handle stdout and stderr as text. Replaces `\r\n` with `\n`.
---   - timeout: (integer) Run the command with a time limit. Upon timeout the process is sent the
---     TERM signal (15) and the exit code is set to 124.
---   - detach: (boolean) If true, spawn the child process in a detached state - this will make it
---     a process group leader, and will effectively enable the child to keep running after the
---     parent exits. Note that the child process will still keep the parent's event loop alive
---     unless the parent process calls |uv.unref()| on the child's process handle.
---
--- @param on_exit? fun(out: vim.SystemCompleted) Called when subprocess exits. When provided, the command runs
---   asynchronously. Receives SystemCompleted object, see return of SystemObj:wait().
---
--- @return vim.SystemObj Object with the fields:
---   - cmd (string[]) Command name and args
---   - pid (integer) Process ID
---   - wait (fun(timeout: integer|nil): SystemCompleted) Wait for the process to complete. Upon
---     timeout the process is sent the KILL signal (9) and the exit code is set to 124. Cannot
---     be called in |api-fast|.
---     - SystemCompleted is an object with the fields:
---       - code: (integer)
---       - signal: (integer)
---       - stdout: (string), nil if stdout argument is passed
---       - stderr: (string), nil if stderr argument is passed
---   - kill (fun(signal: integer|string))
---   - write (fun(data: string|nil)) Requires `stdin=true`. Pass `nil` to close the stream.
---   - is_closing (fun(): boolean)
function M.system(cmd, opts, on_exit)
  if type(opts) == 'function' then
    on_exit = opts
    opts = nil
  end
  return require('please.future._vim._system').run(cmd, opts, on_exit)
end

return M
