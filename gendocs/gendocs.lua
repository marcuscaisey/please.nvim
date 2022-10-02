local docgen = require('docgen')

local inputs = {}
for line in io.lines('/gendocs/doc_files.txt') do
  table.insert(inputs, '/please/' .. line)
end

local output = '/doc/please.txt'
local output_handle = io.open(output, 'w')

for _, input in ipairs(inputs) do
  docgen.write(input, output_handle)
end

output_handle:write(' vim:tw=78:ts=8:ft=help:norl:\n')
output_handle:close()
