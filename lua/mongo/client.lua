local connection_utils = require("mongo.utils.connection")

---@class Client
local Client = {}

---check_is_legacy_async check if the host is legacy or not
---@param workspace Workspace
Client.check_is_legacy_async = function(workspace)
  local connection = workspace.connection
  local extracted_uri = connection_utils.extract_input_uri(connection.uri)
  local full_cmd = {
    workspace.config.mongosh_binary_path,
    extracted_uri.host,
    "--authenticationDatabase",
    extracted_uri.options.authSource or "admin",
    "--quiet",
  }

  local is_legacy = false
  vim
    .system(full_cmd, { text = true }, function(out)
      if (out.stderr or ""):find("MongoServerSelectionError") then
        is_legacy = true
      end
    end)
    :wait()

  return is_legacy
end

---run_command run mongosh or mongo with given args asynchronously
---@param workspace Workspace
---@param args string|string[] eval string arguments pass the mongosh
---@param on_exit fun(out: {code: number, stdout: string, stderr: string}) cb function to call after the command is done
Client.run_async_command = function(workspace, db_name, args, on_exit)
  local connection = workspace.connection
  local host = connection.host
  local cmd = workspace.config.mongosh_binary_path
  if connection.is_legacy then
    if workspace.config.mongo_binary_path == nil then
      vim.defer_fn(function()
        vim.notify("Please set mongo_binary_path in the mongo.nvim config", vim.log.levels.ERROR)
      end, 0)
      return
    else
      cmd = workspace.config.mongo_binary_path
    end
  end

  local batch_size_config_string = connection.is_legacy
      and string.format([[DBQuery.batchSize=%d;]], workspace.config.batch_size)
    or string.format([[config.set("displayBatchSize", %d);]], workspace.config.batch_size)

  local full_cmd = {
    cmd,
    host .. "/" .. db_name,
    "--authenticationDatabase",
    connection.options.authSource or "admin",
    "--quiet",
    "--eval",
    string.format([[%s %s]], batch_size_config_string, args),
  }

  if connection.username ~= nil and connection.password ~= nil then
    table.insert(full_cmd, "-u")
    table.insert(full_cmd, connection.username)
    table.insert(full_cmd, "-p")
    table.insert(full_cmd, connection.password)
  end

  return vim.system(full_cmd, { text = true }, function(out)
    on_exit(out)
  end)
end

return Client
