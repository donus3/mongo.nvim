local buffer = require("mongo.buffer")
local ss = require("mongo.session")
local action = require("mongo.actions")

---@class Config
---@field default_url string the default connection string URL
---@field find_on_collection_selected boolean whether to auto query on collection selected
local config = {
  default_url = "mongodb://localhost:27017",
  find_on_collection_selected = false,
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
  local session = ss.new(args[1], Mongo.config)
  buffer.init(session)
  action.init(session)

  -- clean up autocmd when leave
  local group = vim.api.nvim_create_augroup("MongoDBNvimLeave", { clear = true })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    pattern = "*",
    callback = function()
      buffer.clean(session)
    end,
  })
end

return Mongo
