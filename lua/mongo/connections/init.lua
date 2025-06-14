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
  ---@type {}
  options = {},
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
  local result = connection_utils.extract_input_uri(uri)

  self.host = result.host
  self.options = result.options
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

---add_db adds a new database to the list of the databases
---@param workspace Workspace
---@param new_db_name string
function Connection:add_db(workspace, new_db_name)
  local newDatabase = Database:new(new_db_name)
  table.insert(self.databases, newDatabase)
  workspace.tree.root:add_child(Node:new(newDatabase, false, function()
    collection_actions.show_collections_async(workspace, newDatabase)
  end))
end

return Connection
