local connection_utils = require("mongo.utils.connection")

---@class Client
local Client = {}

---check_is_legacy_async check if the host is legacy or not
---the mongo version less than 3.6 is consider legacy (https://www.mongodb.com/docs/v4.4/mongo/)
---if the mongosh_binary_path is not executable, it will fallback to mongo_binary_path
---@param workspace Workspace
---@param on_done fun(is_legacy: boolean)
Client.check_is_legacy_async = function(workspace, on_done)
  local connection = workspace.connection
  local mongosh_path = workspace.config.mongosh_binary_path
  if vim.fn.executable(mongosh_path) == 0 then
    local mongo_path = workspace.config.mongo_binary_path
    if mongo_path ~= nil and vim.fn.executable(mongo_path) == 1 then
      mongosh_path = mongo_path
    else
      vim.defer_fn(function()
        vim.notify("mongo binary not found (tried " .. mongosh_path .. " and legacy fallback)", vim.log.levels.ERROR)
      end, 0)
      on_done(false)
      return
    end
  end

  local extracted_uri = connection_utils.extract_input_uri(connection.uri)
  if extracted_uri.host == nil then
    on_done(false)
    return
  end

  local full_cmd = {
    mongosh_path,
    extracted_uri.host,
    "--authenticationDatabase",
    extracted_uri.options.authSource or "admin",
    "--quiet",
    "--eval",
    "1",
  }

  if extracted_uri.username ~= nil and extracted_uri.password ~= nil then
    table.insert(full_cmd, "-u")
    table.insert(full_cmd, extracted_uri.username)
    table.insert(full_cmd, "-p")
    table.insert(full_cmd, extracted_uri.password)
  end

  local is_legacy = false
  vim.system(full_cmd, { text = true }, function(out)
    if (out.stderr or ""):find("MongoServerSelectionError") then
      is_legacy = true
    end
    on_done(is_legacy)
  end)
end

---run_async_command run mongosh or mongo with given args asynchronously
---if the mongosh_binary_path is not executable, it will fallback to mongo_binary_path
---@param workspace Workspace
---@param db_name string the database name
---@param args string|string[] eval string arguments pass the mongosh
---@param on_exit fun(out: {code: number, stdout: string, stderr: string}) cb function to call after the command is done
Client.run_async_command = function(workspace, db_name, args, on_exit)
  local connection = workspace.connection
  local host = connection.host
  if host == nil or host == "" then
    return
  end

  local cmd = workspace.config.mongosh_binary_path
  if connection.is_legacy then
    cmd = workspace.config.mongo_binary_path
    if cmd == nil or vim.fn.executable(cmd) == 0 then
      vim.defer_fn(function()
        vim.notify("Please set a valid mongo_binary_path for legacy connection", vim.log.levels.ERROR)
      end, 0)
      return
    end
  else
    if vim.fn.executable(cmd) == 0 then
      cmd = workspace.config.mongo_binary_path
      if cmd == nil or vim.fn.executable(cmd) == 0 then
        vim.defer_fn(function()
          vim.notify(
            "mongo binary not found (tried " ..
            (workspace.config.mongosh_binary_path or "nil") .. " and legacy fallback)",
            vim.log.levels.ERROR)
        end, 0)
        return
      end
    end
  end

  local batch_size_config_string = connection.is_legacy
      and string.format([[DBQuery.batchSize=%d;]], workspace.config.batch_size)
      or string.format([[config.set("displayBatchSize", %d);]], workspace.config.batch_size)

  if type(args) == "table" then
    args = table.concat(args, " ")
  end

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
