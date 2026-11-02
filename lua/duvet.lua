local M

M = {
  ---@param opts? DuvetConfig Configuration options for Duvet
  setup = function(opts)
    if opts then M.user_config = opts end

    if vim.g.duvet_defer_startup == true then
      local config = require('duvet.api.config').verify(opts)
      if not config then return end

      if config.enabled then
        vim.cmd [[
            augroup Duvet
                autocmd!
                autocmd VimLeavePre * lua require 'duvet.server':cleanup()
            augroup END
        ]]

        require('duvet.server'):initialize()
      end
    end
  end,
}

return M
