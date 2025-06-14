local buffer = require("mongo.buffer")
local action = require("mongo.actions")
local Workspace = require("mongo.workspaces")

---@class Config
---@field default_url string the default connection string URL
---@field find_on_collection_selected boolean whether to auto query on collection selected
---@field mongo_binary_path string | nil the path of mongo binary
---@field mongosh_binary_path string  the path of mongosh binary
---@field batch_size number the number of documents in a batch
local config = {
  default_url = "mongodb://localhost:27017",
  find_on_collection_selected = false,
  mongo_binary_path = nil,
  mongosh_binary_path = "mongosh",
  batch_size = 100,
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
end

Mongo.connect = function(args)
  local workspace = Workspace:new(args[1], Mongo.config)
  buffer.init(workspace)
  action.init(workspace)
end

return Mongo
