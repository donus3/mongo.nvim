local buffer = require("mongo.buffer")
local action = require("mongo.actions")
local Workspace = require("mongo.workspaces")

---@class Config
---@field default_url string the default connection string URL
---@field find_on_collection_selected boolean whether to auto query on collection selected
---@field mongo_binary_path string | nil binary path for mongodb < v3.6 (legacy) and fallback
---@field mongosh_binary_path string  binary path for modern mongodb shell (mongosh)
---@field batch_size number the number of documents in a batch
---@field auto_install boolean whether to automatically install dependencies
local config = {
  default_url = "mongodb://localhost:27017",
  find_on_collection_selected = false,
  mongo_binary_path = nil,
  mongosh_binary_path = "mongosh",
  node_binary_path = "node",
  mongodb_driver_version = "^7.0.0",
  batch_size = 100,
  auto_install = true,
}

---@class Mongo
local Mongo = {}

---@type Config
Mongo.config = config

---@param args Config?
-- you can define your setup function here. Usually configurations can be merged, accepting outside params and
-- you can also put some validation here for those.
Mongo.setup = function(args)
  Mongo.config = vim.tbl_deep_extend("force", Mongo.config, args or {})

  if Mongo.config.auto_install then
    local client = require("mongo.client")
    client.check_install_dependencies(Mongo.config)
  end
end

Mongo.connect = function(args)
  local workspace = Workspace:new(args[1], Mongo.config)
  buffer.init(workspace)
  action.init(workspace)
end

return Mongo
