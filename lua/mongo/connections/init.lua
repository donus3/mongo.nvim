local json_utils = require("mongo.utils.json")
local connection_utils = require("mongo.utils.connection")
local collection_actions = require("mongo.actions.collection")
local Node = require("mongo.ui.tree").Node
local Database = require("mongo.databases")

---@class Connection
Connection = {
  ---@type string
  name = "",
  ---@type string
  uri = "",
  ---@type Database
  databases = {},
  ---@type boolean
  is_legacy = false,
  ---@type string
  auth_source = "",
  ---@type string
  params = "",
  ---@type string
  username = "",
  ---@type string
  password = "",
  ---@type string
  host = "",
}

Connection.__index = Connection
Connection.__type = "Connection"

---@param name string the session's name
function Connection:new(name, uri, is_legacy)
  local instant = setmetatable({}, Connection)
  instant.name = name
  instant.uri = uri or ""
  instant.is_legacy = is_legacy or false

  return instant
end

---@param uri string
function Connection:set_uri(uri)
  self.uri = uri
  local result = self:extract_input_uri(uri)

  self.host = result.host
  self.auth_source = result.auth_source or "admin"
  self.params = result.params
  self.username = result.username
  self.password = result.password
end

---@param workspace Workspace
---@param db_json_string string session's databases JSON string `['name1', 'name2']`
---@return { ok: boolean }
function Connection:set_db_from_raw_string(workspace, db_json_string)
  if not connection_utils.check_error_from_response(db_json_string).ok then
    return { ok = false }
  end

  --- parse collections JSON string into the table-like
  --- @type string[]
  local database_names = json_utils.decode(db_json_string)
  table.sort(database_names)

  self.databases = {}
  workspace.tree.root.children = nil
  for _, database_name in ipairs(database_names) do
    local newDatabase = Database:new(database_name)
    table.insert(self.databases, newDatabase)
    workspace.tree.root:add_child(Node:new(newDatabase, false, function()
      collection_actions.show_collections_async(workspace, newDatabase)
    end))
  end

  return { ok = true }
end

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

---extract_options extracts authSource and params from URL
---and returns them as table
---@param options string
local extract_options = function(options)
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

---check the input mongo URL and set each part to the corresponding module variable
---host, username, password, authSource, params
---@param url string
function Connection:extract_input_uri(url)
  local result = {}

  -- try to parse the url with username and password
  for username, password, host, options in url:gmatch("mongodb://(.*):(.*)@([%w|:|%d]+[/]?%w*)[/]?(.*)$") do
    result.username = username
    result.password = password
    result.host = host
    local params_and_auth_source = extract_options(options)
    result.selected_db = params_and_auth_source.selected_db
    result.auth_source = params_and_auth_source.auth_source
    result.params = params_and_auth_source.params
  end

  if result.host == nil then
    -- try to parse the url without username and password
    for host, options in url:gmatch("mongodb://([%w|:|%d]+)[/]?(.*)$") do
      result.host = host
      local params_and_auth_source = extract_options(options)
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

  if result.host ~= nil then
    result.host = string.gsub(result.host, "/", "")
  end

  return result
end

return Connection
