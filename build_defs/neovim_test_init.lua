vim.opt.loadplugins = true

package.path = 'third_party/lua/?.lua;third_party/lua/?/init.lua;' .. package.path
package.cpath = 'third_party/lua/?.so;' .. package.cpath

-- Third party dependencies (neovim_github_plugin targets) generate a *.runtimepath file containing the path to the
-- plugin root directory. This way, we can find all of the paths which need to be added to Neovim's runtimepath.
local f = assert(io.popen('find . -name "*.runtimepath" | xargs cat'))
for line in f:lines() do
  vim.opt.runtimepath:append(line)
end
