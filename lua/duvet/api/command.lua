local M = {}

M.install = function()
  require('duvet.core.async').run(function() require('duvet.server.update').install():unwrap() end)
end
M.fetch = function()
  require('duvet.core.async').run(function() require('duvet.server.update').fetch():unwrap() end)
end
M.build = function()
  require('duvet.core.async').run(function() require('duvet.server.update').build():unwrap() end)
end
M.update = function()
  local mode = require('duvet.api.config').advanced.server.update

  if mode == 'fetch' then
    M.fetch()
  elseif mode == 'install' then
    M.install()
  elseif mode == 'build' then
    M.build()
  elseif mode ~= 'none' then
    require('duvet.api.log').notify(
      'Unknown update mode: ' .. '\'' .. mode .. '\'',
      vim.log.levels.ERROR
    )
  end
end
M.show_presence = function()
  local duvet = require 'duvet.server'
  if duvet.manager then duvet.manager:resume() end
end
M.hide_presence = function()
  local duvet = require 'duvet.server'
  if duvet.manager then duvet.manager:hide() end
end
M.suppress_presence = function()
  local duvet = require 'duvet.server'
  if duvet.manager then duvet.manager:suppress() end
end
M.toggle_presence = function()
  local duvet = require 'duvet.server'
  if duvet.manager then duvet.manager:toggle() end
end
M.toggle_presence_suppress = function()
  local duvet = require 'duvet.server'
  if duvet.manager then duvet.manager:toggle_suppress() end
end
M.idle = function()
  local duvet = require 'duvet.server'
  if duvet.manager then duvet.manager:idle() end
end
M.force_idle = function()
  local duvet = require 'duvet.server'
  if duvet.manager then duvet.manager:force_idle() end
end
M.unidle = function()
  local duvet = require 'duvet.server'
  if duvet.manager then duvet.manager:unidle() end
end
M.toggle_idle = function()
  local duvet = require 'duvet.server'
  if duvet.manager then duvet.manager:toggle_idle() end
end
M.toggle_idle_force = function()
  local duvet = require 'duvet.server'
  if duvet.manager then duvet.manager:toggle_idle(true) end
end
M.restart = function()
  vim.schedule(function()
    local duvet = require 'duvet.server'
    if duvet.is_updating then
      require('duvet.api.log').notify('Operation cancelled: Server is updating', vim.log.levels.WARN)
      return
    end

    require('duvet.api.log').debug 'Restarting...'
    local function initialize()
      require('duvet.core.async').run(function() duvet:initialize() end)
    end

    if duvet.manager then duvet.manager:cleanup() end
    if not duvet.tx then return initialize() end
    if not duvet.client then return initialize() end
    if duvet.client:is_closing() then return initialize() end
    if duvet.client.on_close then duvet.client.on_close() end

    duvet.client.on_close = function()
      duvet.client.on_close = nil
      initialize()
    end

    duvet.tx:restart()
  end)
end
M.reconnect = function()
  vim.schedule(function()
    local duvet = require 'duvet.server'
    if duvet.is_updating then
      require('duvet.api.log').notify('Operation cancelled: Server is updating', vim.log.levels.WARN)
      return
    end

    require('duvet.api.log').debug 'Reconnecting...'
    local function initialize()
      require('duvet.api.log').debug 'reconnect: client dead, falling back to initialize'
      require('duvet.core.async').run(function() duvet:initialize() end)
    end

    if not duvet.tx then return initialize() end
    if not duvet.client then return initialize() end
    if duvet.client:is_closing() then return initialize() end

    require('duvet.api.log').debug 'reconnect: sending reconnect event to server'
    duvet.tx:reconnect()
  end)
end
M.shutdown = function()
  local duvet = require 'duvet.server'

  if not duvet.client or duvet.client:is_closing() then
    return require('duvet.api.log').notify('Server is not running', vim.log.levels.INFO)
  end

  duvet.is_updating = false
  duvet:cleanup()
  duvet.tx:shutdown()
  require('duvet.api.log').notify('Stopped server', vim.log.levels.INFO)
end
M.status = function(silent)
  local duvet = require 'duvet.server'
  local status_map = {
    disconnected = 'Disconnected',
    initializing = 'Connecting to server',
    initialized = 'Connected to server',
    connecting = 'Connecting to Duvet',
    connected = 'Handshaking with Duvet',
    ready = 'Connected to Duvet',
  }
  local msg = status_map[duvet.status] or 'Unknown'

  if silent == true then return msg end
  require('duvet.api.log').notify('Status: ' .. msg, vim.log.levels.INFO)
  return msg
end
M.check = function()
  require('duvet.core.async').run(
    function() require('duvet.server.update').check_version():unwrap() end
  )
end
M.version = function()
  require('duvet.core.async').run(function() require('duvet.server.update').version():unwrap() end)
end
M.health = function() vim.cmd 'checkhealth duvet' end

M.features = {
  idle = { path = { 'idle', 'enabled' }, on_disable = function() M.unidle() end },
}

local function handle_feature(feature, enable)
  local feat = M.features[feature]
  if not feat then
    require('duvet.api.log').notify('Unknown option: \'' .. feature .. '\'', vim.log.levels.ERROR)
    return
  end

  local config = require 'duvet.api.config'
  local target = config
  for i = 1, #feat.path - 1 do
    target = target[feat.path[i]]
  end

  local last = feat.path[#feat.path]
  if enable == true then
    target[last] = true
    if feat.on_disable then feat.on_disable() end
  elseif enable == false then
    target[last] = false
    if feat.on_disable then feat.on_disable() end
  else
    target[last] = not target[last]
    if target[last] then
      if feat.on_enable then feat.on_enable() end
    else
      if feat.on_disable then feat.on_disable() end
    end
  end
end

M.commands = {
  enable = {
    default = function() M.show_presence() end,
    action = function(feature) handle_feature(feature, true) end,
  },
  disable = {
    default = function() M.hide_presence() end,
    action = function(feature) handle_feature(feature, false) end,
  },
  toggle = {
    default = function() M.toggle_presence() end,
    action = function(feature) handle_feature(feature) end,
  },
  presence = {
    default = M.toggle_presence,
    subcommands = {
      show = M.show_presence,
      hide = M.hide_presence,
      suppress = M.suppress_presence,
      toggle = M.toggle_presence,
      toggle_suppress = M.toggle_presence_suppress,
    },
  },
  idle = {
    default = M.toggle_idle,
    subcommands = {
      show = M.idle,
      hide = M.unidle,
      toggle = M.toggle_idle,
      force = M.force_idle,
    },
  },
  update = {
    default = M.update,
    subcommands = {
      check = M.check,
      fetch = M.fetch,
      install = M.install,
      build = M.build,
    },
  },
  status = M.status,
  version = M.version,
  restart = M.restart,
  reconnect = M.reconnect,
  shutdown = M.shutdown,
  health = M.health,
  debug = {
    default = function() require('duvet.api.debug').show() end,
    subcommands = {
      copy = function() require('duvet.api.debug').copy() end,
    },
  },
}

M.get_commands = function()
  local cmds = {}
  for cmd, _ in pairs(M.commands) do
    table.insert(cmds, cmd)
  end
  return cmds
end

M.get_subcommands = function(cmd)
  local command = M.commands[cmd]
  if type(command) ~= 'table' or not command.subcommands then return {} end

  local subcmds = {}
  for subcmd, _ in pairs(command.subcommands) do
    table.insert(subcmds, subcmd)
  end
  return subcmds
end

M.get_features = function()
  local feats = {}
  for feat, _ in pairs(M.features) do
    table.insert(feats, feat)
  end
  return feats
end

M.handle = function(q_args)
  if not q_args then
    require('duvet.api.log').notify('No command provided', vim.log.levels.ERROR)
    return
  end

  if type(q_args) ~= 'string' then
    require('duvet.api.log').notify(
      'Invalid input: expected string, got ' .. tostring(q_args),
      vim.log.levels.ERROR
    )
    return
  end

  local args = vim.split(string.gsub(q_args, '"', ''), '%s+')
  local args_len = #args
  if args_len == 0 then
    require('duvet.api.log').notify('No command provided', vim.log.levels.ERROR)
    return
  end

  local cmd = args[1]
  local command = M.commands[cmd]

  if not command then
    require('duvet.api.log').notify('Unknown command: \'' .. cmd .. '\'', vim.log.levels.ERROR)
    return
  end

  local execute
  if type(command) == 'function' then
    execute = command
  else
    execute = command.default
  end

  if args_len == 1 then
    execute()
    return
  end

  local subcmd = args[2]
  if not subcmd then
    require('duvet.api.log').notify('Additional arguments required', vim.log.levels.ERROR)
    return
  end

  if type(command) == 'table' then
    if command.subcommands and command.subcommands[subcmd] then
      command.subcommands[subcmd]()
    elseif command.action then
      command.action(subcmd)
    else
      require('duvet.api.log').notify(
        'Unknown option: \'' .. subcmd .. '\' for command \'' .. cmd .. '\'',
        vim.log.levels.ERROR
      )
    end
  else
    require('duvet.api.log').notify(
      'Unknown subcommand: \'' .. subcmd .. '\' for command \'' .. cmd .. '\'',
      vim.log.levels.ERROR
    )
  end
end

return M
