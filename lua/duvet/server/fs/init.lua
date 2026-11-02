local M = {}

function M.get_plugin_root()
  local source = debug.getinfo(1, 'S').source:sub(2)
  return vim.fn.fnamemodify(source, ':h:h:h:h:h')
end

function M.get_data_path() return vim.fn.stdpath 'data' .. '/duvet' end

---@param config? DuvetConfig
function M.get_executable_path(config)
  return (config and config.advanced.server.executable_path or M.get_data_path())
    .. '/bin/'
    .. M.get_executable_name()
end

function M.get_executable_name()
  return require('duvet.core.util').get_os().name == 'windows' and 'duvet.exe' or 'duvet'
end

return M
