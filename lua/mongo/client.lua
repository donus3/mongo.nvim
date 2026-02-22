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

---Read the installed mongodb driver version from node_modules
---@param node_dir string
---@return string|nil version string or nil if not installed
local function get_installed_version(node_dir)
  local pkg_path = node_dir .. "/node_modules/mongodb/package.json"
  if vim.fn.filereadable(pkg_path) == 0 then
    return nil
  end
  local ok, pkg_json = pcall(function()
    local content = vim.fn.readfile(pkg_path)
    return vim.fn.json_decode(table.concat(content, "\n"))
  end)
  if ok and pkg_json then
    return pkg_json.version
  end
  return nil
end

---Check if an installed version satisfies a semver range
---@param installed string e.g. "7.1.0"
---@param range string e.g. "^7.0.0", "~7.0.0", "7.0.0", ">=7.0.0"
---@return boolean
local function version_satisfies(installed, range)
  local function parse_version(v)
    local major, minor, patch = v:match("^(%d+)%.(%d+)%.(%d+)")
    if major then
      return { tonumber(major), tonumber(minor), tonumber(patch) }
    end
    return nil
  end

  -- Strip leading semver range operator and parse the base version
  local operator, base = range:match("^([~^>=<]*)(.+)$")
  local inst = parse_version(installed)
  local req = parse_version(base)
  if not inst or not req then
    return false
  end

  if operator == "^" then
    -- ^major.minor.patch: allow changes that do not modify the left-most non-zero digit
    if req[1] > 0 then
      return inst[1] == req[1]
        and (inst[2] > req[2] or (inst[2] == req[2] and inst[3] >= req[3]))
    end
    -- ^0.minor.patch
    if req[2] > 0 then
      return inst[1] == 0
        and inst[2] == req[2]
        and inst[3] >= req[3]
    end
    -- ^0.0.patch
    return inst[1] == 0 and inst[2] == 0 and inst[3] == req[3]
  elseif operator == "~" then
    return inst[1] == req[1] and inst[2] == req[2] and inst[3] >= req[3]
  elseif operator == ">=" then
    return inst[1] > req[1]
      or (inst[1] == req[1] and inst[2] > req[2])
      or (inst[1] == req[1] and inst[2] == req[2] and inst[3] >= req[3])
  elseif operator == "" then
    return inst[1] == req[1] and inst[2] == req[2] and inst[3] == req[3]
  end

  -- Unknown operator, fallback to exact match
  return installed == range
end

---Check if dependencies are installed and install them if missing
---@param config Config
Client.check_install_dependencies = function(config)
  local node_dir = get_node_dir()
  local mongodb_version = config.mongodb_driver_version or "^7.0.0"

  local needs_install = false
  local installed = get_installed_version(node_dir)

  if not installed then
    needs_install = true
  elseif not version_satisfies(installed, mongodb_version) then
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
