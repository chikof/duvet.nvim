local async = require 'duvet.core.async'
local logger = require 'duvet.api.log'

local M = {}

local function get_os_info()
  local uv = vim.loop or vim.uv
  local uname = uv.os_uname()
  return {
    sysname = uname.sysname,
    release = uname.release,
    version = uname.version,
    machine = uname.machine,
    wsl = os.getenv 'WSL_DISTRO_NAME',
  }
end

local function get_git_sha()
  local root = require('duvet.server.fs').get_plugin_root()
  local fs = require 'duvet.core.uv.fs'
  local git_dir = fs.stat(root .. '/.git'):await()
  if not git_dir then return 'unknown' end

  if not vim.fn.executable 'git' then return 'git not found' end

  local process = require 'duvet.core.uv.process'
  local res = process
    .spawn({
      cmd = 'git',
      args = { 'rev-parse', '--short', 'HEAD' },
      cwd = root,
    })
    :await()

  if not res or res.code ~= 0 then return 'unknown' end
  local sha = res.stdout:gsub('^%s*(.-)%s*$', '%1')
  if sha == '' then return 'unknown' end
  return sha
end

local function get_server_info()
  local fs = require 'duvet.core.uv.fs'
  local config = require('duvet.api.config').get()
  local exec_path = require('duvet.server.fs').get_executable_path(config)
  local stat = fs.stat(exec_path):await()
  if not stat then return { version = 'not installed', path = exec_path, executable = false } end

  local is_windows = get_os_info().sysname:lower():match 'windows'
  local is_exec = true
  if not is_windows then is_exec = vim.fn.executable(exec_path) == 1 end

  local version = 'unknown'
  if is_exec then
    local process = require 'duvet.core.uv.process'
    local res = process
      .spawn({
        cmd = exec_path,
        args = { '-v' },
      })
      :await()

    if res and res.code == 0 then
      version = res.stdout:gsub('^%s*(.-)%s*$', '%1')
      if version == '' then version = 'unknown' end
    end
  end

  return { version = version, path = exec_path, executable = is_exec }
end

local function get_server_metadata()
  local fs = require 'duvet.core.uv.fs'
  local path = require('duvet.server.fs').get_plugin_root() .. '/.github/server-metadata.txt'
  local content = fs.readfile(path):await()
  if not content then return nil end
  local trimmed = content:gsub('^%s*(.-)%s*$', '%1')
  if trimmed == '' then return nil end
  return trimmed
end

local function get_status()
  local duvet = require 'duvet.server'
  local status_map = {
    disconnected = 'disconnected',
    initializing = 'initializing',
    initialized = 'connected to server',
    connecting = 'connecting to duvet',
    connected = 'connected to duvet',
    ready = 'connected to duvet',
  }
  local status = status_map[duvet.status] or 'unknown'

  local pipe_path = require('duvet.api.config').get().advanced.server.pipe_path
    or require('duvet.core.util').get_pipe_path()

  local fs = require 'duvet.core.uv.fs'
  local pipe_exists = false
  local stat = fs.stat(pipe_path):await()
  if stat then pipe_exists = true end

  local client_alive = duvet.client and not duvet.client:is_closing()
  local manager_alive = duvet.manager ~= nil

  return {
    status = status,
    pipe_path = pipe_path,
    pipe_exists = pipe_exists,
    client_alive = client_alive,
    manager_alive = manager_alive,
  }
end

local function probe_pipe(path)
  local pipe = require('duvet.core.uv.pipe').new()
  local _, err = pipe:connect(path):await()
  pipe:close()
  return err == nil
end

local function check_duvet_pipe()
  local config = require('duvet.api.config').get()
  local custom = config.advanced.duvet.pipe_paths
  local is_windows = get_os_info().sysname:lower():match 'windows'

  local function get_paths()
    if custom and #custom > 0 then return custom end
    if is_windows then return { '\\\\.\\pipe\\duvet-ipc' } end

    local dir = os.getenv 'XDG_RUNTIME_DIR'
    for _, name in ipairs { 'TMPDIR', 'TMP', 'TEMP' } do
      if dir and dir ~= '' then break end
      dir = os.getenv(name)
    end
    if not dir or dir == '' then dir = '/tmp' end

    local path = dir:gsub('/+$', '') .. '/duvet-ipc.sock'
    local stat = (vim.loop or vim.uv).fs_stat(path)
    return stat and stat.type == 'socket' and { path } or {}
  end

  local paths = get_paths()
  if #paths == 0 then return {} end

  local results = {}
  for _, path in ipairs(paths) do
    local ok = probe_pipe(path)
    results[#results + 1] = { path = path, reachable = ok }
  end
  return results
end

local function build_report()
  local lines = {}

  local function section(title)
    table.insert(lines, '')
    table.insert(lines, '### ' .. title)
    table.insert(lines, '')
  end

  local function kv(key, val) table.insert(lines, '**`' .. key .. '`**: `' .. tostring(val) .. '`') end

  local function code_block(lang, text)
    table.insert(lines, '```' .. lang)
    for _, line in ipairs(vim.split(text, '\n')) do
      table.insert(lines, line)
    end
    table.insert(lines, '```')
  end

  section 'version'
  local server = get_server_info()
  kv('server', server.version)
  kv('executable', server.executable)
  kv('executable path', server.path)
  kv('git sha', get_git_sha())
  kv('server metadata', get_server_metadata() or 'not found')
  kv('neovim', tostring(vim.version()))
  kv('lua', _VERSION .. (jit and ' (luajit)' or ''))

  if not server.executable then
    section 'warnings'
    table.insert(lines, '- server is not executable')
  else
    section 'warnings'
    local has_warnings = false
    if vim.fn.executable 'curl' ~= 1 then
      table.insert(lines, '- curl not found')
      has_warnings = true
    end
    if not has_warnings then table.insert(lines, 'none') end
  end

  section 'status'
  local status = get_status()
  kv('status', status.status)
  kv('pipe path', status.pipe_path)
  kv('pipe exists', status.pipe_exists)
  kv('client alive', status.client_alive)
  kv('manager alive', status.manager_alive)

  section 'duvet ipc'
  local custom = require('duvet.api.config').get().advanced.duvet.pipe_paths
  if custom and #custom > 0 then table.insert(lines, '(using custom pipe paths)') end
  local pipes = check_duvet_pipe()
  if #pipes == 0 then
    table.insert(lines, 'none found')
  else
    for _, p in ipairs(pipes) do
      table.insert(
        lines,
        '- `' .. p.path .. '`: ' .. (p.reachable and 'reachable' or 'unreachable')
      )
    end
  end

  section 'os'
  local os_info = get_os_info()
  kv('sysname', os_info.sysname)
  kv('release', os_info.release)
  kv('machine', os_info.machine)
  if os_info.wsl then kv('wsl', os_info.wsl) end

  section 'config validation'
  local results = require('duvet.api.config').validate(require('duvet').user_config)
  if results.is_valid then
    table.insert(lines, 'no issues found')
  else
    for _, err in ipairs(results.errors) do
      table.insert(lines, '- error: ' .. err.msg)
      if err.hint then table.insert(lines, '  hint: ' .. err.hint) end
    end
    for _, warn in ipairs(results.warnings) do
      table.insert(lines, '- warning: ' .. warn)
    end
  end

  section 'config (user)'
  local user_config = require('duvet').user_config or {}
  if next(user_config) == nil then
    table.insert(lines, '(none)')
  else
    code_block('lua', vim.inspect(user_config))
  end

  section 'config (merged)'
  local merged = require('duvet.api.config').get()
  code_block('lua', vim.inspect(merged))

  return table.concat(lines, '\n')
end

M.report = async.wrap(function() return build_report() end)

M.show = function()
  async.run(function()
    local report = M.report():unwrap()
    vim.schedule(function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(report, '\n'))
      vim.bo[buf].filetype = 'markdown'
      vim.api.nvim_win_set_buf(0, buf)
      vim.api.nvim_buf_set_name(buf, 'duvet_debug')
    end)
  end)
end

M.copy = function()
  async.run(function()
    local report = M.report():unwrap()
    vim.schedule(function()
      vim.fn.setreg('+', report)
      logger.notify('copied to clipboard', vim.log.levels.INFO)
    end)
  end)
end

return M
