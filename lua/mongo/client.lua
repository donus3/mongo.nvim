local connection_utils = require("mongo.utils.connection")

---@class Client
local Client = {}

---Get the path to the node directory
---@return string
local function get_node_dir()
  local script_path = debug.getinfo(1).source:match("@(.*)$")
  return script_path:gsub("lua/mongo/client.lua", "node")
end

---Get the path to the node executor script
---@return string
local function get_executor_path()
  return get_node_dir() .. "/executor.js"
end

---Check if dependencies are installed and install them if missing
---@param config Config
Client.check_install_dependencies = function(config)
  local node_dir = get_node_dir()
  local pkg_path = node_dir .. "/package.json"
  local mongodb_version = config.mongodb_driver_version or "^7.0.0"

  local needs_install = false

  -- Check if package.json exists and has the correct version
  if vim.fn.filereadable(pkg_path) == 1 then
    local pkg_content = vim.fn.readfile(pkg_path)
    local pkg_json = vim.fn.json_decode(table.concat(pkg_content, "\n"))

    if not pkg_json.dependencies or pkg_json.dependencies.mongodb ~= mongodb_version then
      needs_install = true
    end
  else
    needs_install = true
  end

  -- Also check if node_modules exists
  if vim.fn.isdirectory(node_dir .. "/node_modules") == 0 then
    needs_install = true
  end

  if needs_install then
    vim.notify(
      "mongo.nvim: Missing or incorrect Node.js dependencies. Installing mongodb@" .. mongodb_version .. "...",
      vim.log.levels.INFO
    )
    vim.system({ "npm", "install", "mongodb@" .. mongodb_version }, { cwd = node_dir }, function(out)
      if out.code == 0 then
        vim.schedule(function()
          vim.notify("mongo.nvim: Dependencies installed successfully.", vim.log.levels.INFO)
        end)
      else
        vim.schedule(function()
          vim.notify(
            "mongo.nvim: Failed to install dependencies. Please run 'npm install mongodb@"
              .. mongodb_version
              .. "' manually in "
              .. node_dir,
            vim.log.levels.ERROR
          )
          if out.stderr and out.stderr ~= "" then
            vim.notify("npm error: " .. out.stderr, vim.log.levels.ERROR)
          end
        end)
      end
    end)
  end
end

---check_is_legacy_async check if the host is legacy or not
---Note: With the Node driver, we might not need this distinction as much,
---but we keep it for compatibility if we still want to detect legacy servers.
---@param workspace Workspace
---@param on_done fun(is_legacy: boolean)
Client.check_is_legacy_async = function(workspace, on_done)
  local connection = workspace.connection
  local node_path = workspace.config.node_binary_path or "node"

  if vim.fn.executable(node_path) == 0 then
    vim.defer_fn(function()
      vim.notify("node binary not found: " .. node_path, vim.log.levels.ERROR)
    end, 0)
    on_done(false)
    return
  end

  local extracted_uri = connection_utils.extract_input_uri(connection.uri)
  if extracted_uri.host == nil then
    on_done(false)
    return
  end

  -- We call the executor with a simple query to test connectivity
  local full_cmd = {
    node_path,
    get_executor_path(),
    connection.uri,
    "admin", -- default DB for checking
    "db.adminCommand({ ping: 1 })",
  }

  local is_legacy = false
  vim.system(full_cmd, { text = true }, function(out)
    -- If it fails with specific errors, we might flag as legacy or just error
    if out.code ~= 0 then
      if (out.stderr or ""):find("MongoServerSelectionError") then
        is_legacy = true
      end
    end
    on_done(is_legacy)
  end)
end

---run_async_command run node executor with given args asynchronously
---@param workspace Workspace
---@param db_name string the database name
---@param args string|string[] query string or table of lines
---@param on_exit fun(out: {code: number, stdout: string, stderr: string}) cb function to call after the command is done
Client.run_async_command = function(workspace, db_name, args, on_exit)
  local connection = workspace.connection
  local node_path = workspace.config.node_binary_path or "node"

  if vim.fn.executable(node_path) == 0 then
    vim.defer_fn(function()
      vim.notify("node binary not found: " .. node_path, vim.log.levels.ERROR)
    end, 0)
    return
  end

  if type(args) == "table" then
    args = table.concat(args, "\n")
  end

  -- We incorporate the batch size into the query if possible,
  -- although the driver handles results differently.
  -- For now, we'll let the user's query handle .limit() etc.

  local full_cmd = {
    node_path,
    get_executor_path(),
    connection.uri,
    db_name,
    args,
  }

  return vim.system(full_cmd, { text = true }, function(out)
    on_exit(out)
  end)
end

return Client
