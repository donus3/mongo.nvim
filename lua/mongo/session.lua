local constant = require("mongo.constant")

---@class Sessions
local Session = {}

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
---@field dbs_filtered string[]
---@field is_legacy boolean | nil
---@field query_buf number | nil
---@field query_win number | nil
---@field result_buf number | nil
---@field result_win number | nil
---@field connection_buf number | nil
---@field connection_win number | nil
---@field collection_buf number | nil
---@field collection_win number | nil
---@field database_buf number | nil
---@field database_win number | nil
---@field tabpage_num number | nil
---@field config Config | nil

---@type { [string]: Session }
Session.sessions = {}

---get_params_and_auth_source extracts authSource and params from options
---and returns them as table
---@param params string
---@return table
local get_params_and_auth_source = function(params)
  local result = {}

  if params ~= nil then
    for auth_source in params:gmatch("[&]?auth[S|s]ource=([%w_-]+)[&]?") do
      if auth_source ~= nil then
        result.auth_source = auth_source
      end
    end

    local excludeAuthSourceOptions = params:gsub("[&]?authSource=[%w_-]+[&]?", "")
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
      for db_name, _, params in options:gmatch("([%w_-]+)(%??)(.*)$") do
        if db_name ~= nil then
          result.selected_db = db_name
        end
        if params ~= "" then
          local params_and_auth_source = get_params_and_auth_source(params)
          result.auth_source = params_and_auth_source.auth_source
          result.params = params_and_auth_source.params
        end
      end
    else
      local params_and_auth_source = get_params_and_auth_source(options)
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
    result.selected_db = params_and_auth_source.selected_db
    result.auth_source = params_and_auth_source.auth_source
    result.params = params_and_auth_source.params
  end

  if result.host == nil then
    -- try to parse the url without username and password
    for host, options in url:gmatch("mongodb://([%w|:|%d]+)[/]?(.*)$") do
      result.host = host
      local params_and_auth_source = extract_options(url, options)
      result.selected_db = params_and_auth_source.selected_db
      result.auth_source = params_and_auth_source.auth_source
      result.params = params_and_auth_source.params
    end
  end

  if result.host == nil then
    vim.defer_fn(function()
      vim.notify(
        "Unsupported mongodb URL "
          .. url
          .. ". Please use mongodb://username:password@host[/db_name][/?options] or mongodb://host[/db_name][/?options]",
        vim.log.levels.ERROR
      )
    end, 0)
  end

  return result
end

---new creates a new session and add it to the sessions
---@param name string|nil the session name
---@param config Config
---@return Session new_session new empty session
Session.new = function(name, config)
  if name ~= nil and Session.get(name) ~= nil then
    return Session.get(name)
  end

  local session_name = name
  if session_name == nil then
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
    dbs_filtered = {},
    is_legacy = nil,
    query_buf = nil,
    query_win = nil,
    result_buf = nil,
    result_win = nil,
    collection_buf = nil,
    collection_win = nil,
    connection_buf = nil,
    connection_win = nil,
    database_buf = nil,
    database_win = nil,
    tabpage_num = nil,
    config = config,
  }
  Session.sessions[session_name] = new_session
  return new_session
end

--=set_url sets url parts to the session identified by name
---@param name string the session name
---@param url string the mongodb url to be set
Session.set_url = function(name, url)
  local parts = checkHost(url)
  local session = Session.sessions[name]
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
Session.set_session_field = function(name, field, value)
  if Session.sessions[name] then
    Session.sessions[name][field] = value
  end
end

---list returns all sessions
---@return Session[]
Session.list = function()
  return Session.sessions
end

---list returns all sessions
---@return Session[]
Session.list_names = function()
  local names = {}
  for k, v in pairs(Session.sessions) do
    if v ~= nil then
      table.insert(names, k)
    end
  end
  return names
end

---get gets a session from the sessions by name
---@param name string the session name to be retrieved
---@return Session
Session.get = function(name)
  return Session.sessions[name]
end

---rename session
---@param oldName string
---@param newName string
Session.renameSession = function(oldName, newName)
  local target = Session.sessions[oldName]
  target.name = newName

  local toRename = {
    "result",
    "query",
    "collection",
  }

  for _, v in ipairs(toRename) do
    if target[v .. "_buf"] then
      vim.defer_fn(function()
        vim.api.nvim_buf_set_name(target[v .. "_buf"], constant[v .. "_buf_name"] .. " : " .. target.name)
      end, 0)
    end
  end

  Session.sessions[newName] = target
  Session.sessions[oldName] = nil
end

---remove a session out of the sessions
---@param name string the session name to be removed
Session.remove = function(name)
  Session.sessions[name] = nil
end

---get_host returns the host of the session
---@param name string the session name
---@return string
Session.get_host = function(name)
  local session = Session.get(name)
  if session == nil then
    return ""
  end

  if session.host == nil then
    return ""
  end

  ---@type string
  local host = session.host

  if session.selected_db ~= nil then
    host = host .. "/" .. session.selected_db
  end

  if session.params ~= nil and session.params ~= "" then
    host = host .. "/" .. session.params
  end

  return host
end

return Session
