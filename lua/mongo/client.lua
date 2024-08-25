local ss = require("mongo.session")

---@class Client
local Client = {}

---check_is_legacy_async check if the host is legacy or not
---@param session Session
---@param cb fun()
Client.check_is_legacy_async = function(session, cb)
  local host = ss.get_host(session.name)
  local full_cmd = {
    session.config.mongosh_binary_path,
    host,
    "--authenticationDatabase",
    session.auth_source,
    "--quiet",
  }

  vim.system(full_cmd, { text = true }, function(out)
    if (out.stderr or ""):find("MongoServerSelectionError") then
      ss.set_session_field(session.name, "is_legacy", true)
    else
      ss.set_session_field(session.name, "is_legacy", false)
    end
    cb()
  end)
end

---run_command run mongosh or mongo with given args asynchronously
---@param session Session
---@param args string eval string arguments pass the mongosh
---@param on_exit fun(out: {code: number, stdout: string, stderr: string}) cb function to call after the command is done
Client.run_async_command = function(session, args, on_exit)
  vim.defer_fn(function()
    -- disable the back keymaps while running the command
    vim.keymap.set("n", "-", "", { buffer = session.connection_buf })
  end, 0)

  local host = ss.get_host(session.name)
  local cmd = session.config.mongosh_binary_path
  if session.is_legacy then
    if session.config.mongo_binary_path == nil then
      vim.defer_fn(function()
        vim.notify("Please set mongo_binary_path in the mongo.nvim config", vim.log.levels.ERROR)
      end, 0)
      return
    end

    cmd = session.config.mongo_binary_path
  end

  local batch_size_config_string = session.is_legacy
      and string.format([[DBQuery.batchSize=%d;]], session.config.batch_size)
      or string.format([[config.set("displayBatchSize", %d);]], session.config.batch_size)

  local full_cmd = {
    cmd,
    host,
    "--authenticationDatabase",
    session.auth_source,
    "--quiet",
    "--eval",
    string.format([[%s %s]], batch_size_config_string, args),
  }

  if session.username ~= nil and session.password ~= nil then
    table.insert(full_cmd, "-u")
    table.insert(full_cmd, session.username)
    table.insert(full_cmd, "-p")
    table.insert(full_cmd, session.password)
  end

  return vim.system(full_cmd, { text = true }, function(out)
    on_exit(out)
  end)
end

return Client
