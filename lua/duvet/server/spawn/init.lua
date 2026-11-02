local async = require 'duvet.core.async'
local Future = require 'duvet.core.async.future'
local M = {}

M.spawn = async.wrap(function(config, pipe_path)
  return Future.new(function(resolve, reject)
    local logger = require 'duvet.api.log'
    local update_strategy = config.advanced.server.update
    local exec_path = require('duvet.server.fs').get_executable_path(config)

    local fs = require 'duvet.core.uv.fs'
    local stat = fs.stat(exec_path):await()
    if not stat then
      logger.debug('Spawn: executable missing at ' .. tostring(exec_path))
      if update_strategy == 'fetch' then
        require('duvet.server.update').fetch():unwrap()
      elseif update_strategy == 'install' then
        require('duvet.server.update').install():unwrap()
      elseif update_strategy == 'build' then
        require('duvet.server.update').build():unwrap()
      else
        require('duvet.api.log').error 'Could not find the server executable'
      end
      return resolve(false, false)
    end

    local process = require 'duvet.core.uv.process'
    process.spawn_daemon {
      cmd = exec_path,
      args = {
        '-p',
        pipe_path,
        '-t',
        config.advanced.server.timeout,
        '-r',
        config.advanced.duvet.reconnect.enabled and config.advanced.duvet.reconnect.interval
          or 0,
        config.advanced.duvet.reconnect.initial and '-i' or nil,
      },
      on_stdout = function(data)
        if data:match 'Ready' then
          logger.debug 'Spawn: server signaled Ready'
          resolve(true, false)
        end
      end,
      on_stderr = function(err)
        if err:match 'another instance is running' then
          logger.debug 'Spawn: another instance detected; will retry connect'
          resolve(true, true)
          return
        end

        logger.debug('Spawn: stderr: ' .. tostring(err))
        reject(err)
      end,
      on_error = function(err)
        logger.debug('Spawn: on_error: ' .. tostring(err))
        reject(err)
      end,
    }
  end)
end)

return M
