local popup = require 'please.runners.popup'
local tmux = require 'please.runners.tmux'

return {
  popup = popup.run,
  tmux = tmux.run,
}
