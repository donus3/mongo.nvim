local json_utils = require("mongo.utils.json")
local connection_utils = require("mongo.utils.connection")
local Collection = require("mongo.collections")
local constant = require("mongo.constant")

---@class Database
Database = {
  ---@type string
  name = "",
  ---@type Collection
  collections = {},
}

Database.__index = Database
Database.__type = "Database"

---@param name string the database's name
---@return Database
function Database:new(name)
  local instance = setmetatable({}, Database)
  instance.name = name
  return instance
end

---@param workspace Workspace
---@param collection_json_string string database's collections JSON string `['name1', 'name2']`
function Database:set_collections_from_raw_string(workspace, collection_json_string)
  if not connection_utils.check_error_from_response(collection_json_string).ok then
    return { ok = false }
  end

  --- parse collections JSON string into the table-like
  --- @type string[]
  local collection_names = json_utils.decode(collection_json_string)
  table.sort(collection_names)

  local result = workspace.tree:find_node(self.name, "Database")
  local database_node = result.target
  if database_node == nil then
    vim.notify("Database node not found", vim.log.levels.ERROR)
    return { ok = false }
  end

  self.collections = {}
  database_node.children = nil
  for _, collection_name in ipairs(collection_names) do
    local collection = Collection:new(collection_name)
    database_node:add_child(Node:new(collection, false, function()
      vim.api.nvim_buf_set_name(
        workspace.space.query.buf,
        constant.workspace .. workspace.name .. constant.query_buf_name .. database_node.value.name
      )
      Collection_actions.select_collection(workspace, collection, database_node.value.name)
    end))
    table.insert(self.collections, collection)
  end

  return { ok = true }
end

return Database
