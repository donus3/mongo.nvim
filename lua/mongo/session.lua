local constant = require("mongo.constant")

---@class Sessions
local M = {}

---@class Session
---@field name string
---@field url string | nil
---@field host string | nil
---@field username string | nil
---@field password string | nil
---@field auth_source string | nil
---@field params string | nil
---@field selected_collection string | nil
---@field selected_db string | nil
---@field collections string[]
---@field query_win_number number | nil
---@field result_win_number number | nil
---@field dbs_filtered string[]
---@field current_state string state machine: init -> connected -> db_selected -> collection_selected
---@field is_legacy boolean | nil
---@field command_buf number | nil
---@field command_win number | nil
---@field result_buf number | nil
---@field result_win number | nil
---@field connection_buf number | nil
---@field connection_win number | nil
---@field tabpage_num number | nil

---@type { [string]: Session }
M.sessions = {}

---get_params_and_auth_source extracts authSource and params from options
---and returns them as table
---@param params string
---@param options string
---@return table
local get_params_and_auth_source = function(params, options)
  local result = {}

  if params ~= nil then
    for authSource in params:gmatch("[&]?auth[S|s]ource=(%w+)[&]?") do
      if authSource ~= nil then
        result.auth_source = authSource
      end
    end

    local excludeAuthSourceOptions = options:gsub("[&]?authSource=%w+[&]?", "")
    if excludeAuthSourceOptions ~= nil and excludeAuthSourceOptions ~= "?" then
      result.params = excludeAuthSourceOptions
    end
  end

  return result
end

---extract_options extracts authSource and params from url
---and returns them as table
---@param url string
---@param options string
local extract_options = function(url, options)
  local result = {}

  if options ~= nil then
    if options:match("^%?.*$") == nil then
      -- there is a db name in the URL
      for db_name, params in url:gmatch("(%w+)(/%?.*)$") do
        result.selected_db = db_name
        local params_and_auth_source = get_params_and_auth_source(params, options)
        result.auth_source = params_and_auth_source.auth_source
        result.params = params_and_auth_source.params
      end
    else
      local params_and_auth_source = get_params_and_auth_source(options, options)
      result.auth_source = params_and_auth_source.auth_source
      result.params = params_and_auth_source.params
    end
  end

  return result
end

---check the input mongo url and set each part to the corresponding module variable
---host, username, password, authSource, params
---@param url string
local checkHost = function(url)
  local result = {}

  -- try to parse the url with username and password
  for username, password, host, options in url:gmatch("mongodb://(.*):(.*)@([%w|:|%d]+[/]?%w*)[/]?(.*)$") do
    result.username = username
    result.password = password
    result.host = host
    local params_and_auth_source = extract_options(url, options)
    result.auth_source = params_and_auth_source.auth_source
    result.params = params_and_auth_source.params
  end

  if result.host == nil then
    -- try to parse the url without username and password
    for host, options in url:gmatch("mongodb://([%w|:|%d]+)[/]?(.*)$") do
      result.host = host
      local params_and_auth_source = extract_options(url, options)
      result.auth_source = params_and_auth_source.auth_source
      result.params = params_and_auth_source.params
    end
  end

  if result.host == nil then
    vim.notify(
      "Unsupported mongodb URL "
        .. url
        .. ". Please use mongodb://username:password@host[/db_name][/?options] or mongodb://host[/db_name][/?options]",
      vim.log.levels.ERROR
    )
  end

  for host, db_name in result.host:gmatch("(.*)/(.*)") do
    if db_name ~= nil then
      result.host = host
      result.selected_db = db_name
    end
  end

  return result
end

---new creates a new session and add it to the sessions
---@param name string|nil the session name
---@return Session new_session new empty session
M.new = function(name)
  local session_name = name
  if name == nil then
    local now = os.clock()
    session_name = "temp__" .. now
  end

  local new_session = {
    name = session_name,
    url = "",
    host = nil,
    username = nil,
    password = nil,
    auth_source = nil,
    params = nil,
    selected_collection = nil,
    selected_db = nil,
    collections = {},
    query_win_number = nil,
    result_win_number = nil,
    dbs_filtered = {},
    current_state = constant.state.init,
    is_legacy = nil,
    command_buf = nil,
    command_win = nil,
    result_buf = nil,
    result_win = nil,
    connection_buf = nil,
    connection_win = nil,
    tabpage_num = nil,
  }
  M.sessions[session_name] = new_session
  return new_session
end

--=set_url sets url parts to the session identified by name
---@param name string the session name
---@param url string the mongodb url to be set
M.set_url = function(name, url)
  local parts = checkHost(url)
  local session = M.sessions[name]
  session.url = url
  session.host = parts.host
  session.selected_db = parts.selected_db
  session.username = parts.username
  session.password = parts.password
  session.auth_source = parts.auth_source or "admin"
  session.params = parts.params
end

---set_session_fields sets the fields of the session
---@param name string the session name
---@param field string the fields to be set
---@param value any the value to be set
M.set_session_field = function(name, field, value)
  if M.sessions[name] then
    M.sessions[name][field] = value
  end
end

---list returns all sessions
---@return Session[]
M.list = function()
  return M.sessions
end

---list returns all sessions
---@return Session[]
M.list_names = function()
  local names = {}
  for k, _ in pairs(M.sessions) do
    table.insert(names, k)
  end
  return names
end

---get gets a session from the sessions by name
---@param name string the session name to be retrieved
---@return Session
M.get = function(name)
  return M.sessions[name]
end

---rename session
---@param oldName string
---@param newName string
M.renameSession = function(oldName, newName)
  local target = M.sessions[oldName]
  target.name = newName
  if target.connection_buf then
    vim.api.nvim_buf_set_name(target.connection_buf, constant.connection_buf_name .. target.name)
  end
  if target.command_buf then
    vim.api.nvim_buf_set_name(target.command_buf, constant.command_buf_name .. target.name)
  end
  if target.result_buf then
    vim.api.nvim_buf_set_name(target.result_buf, constant.command_buf_name .. target.name)
  end

  M.sessions[newName] = target
  M.sessions[oldName] = nil
end

---remove a session out of the sessions
---@param name string the session name to be removed
M.remove = function(name)
  M.sessions[name] = nil
end

---get_host returns the host of the session
---@param name string the session name
---@return string
M.get_host = function(name)
  local session = M.get(name)
  if session == nil then
    return ""
  end

  if session.host == nil then
    return ""
  end

  ---@type string
  local host = session.host

  if M.selected_db ~= nil then
    host = host .. "/" .. M.selected_db
  end

  if M.params ~= nil then
    host = host .. "/" .. M.params
  end

  return host
end

return M
