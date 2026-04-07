-- This module exposes the please binary to be used by anything which needs to run a please command.
-- By default it's the plz binary found on PATH, but this can be overriden with the PLEASE_NVIM_PLZ environment
-- variable.
return os.getenv('PLEASE_NVIM_PLZ') or 'plz'
