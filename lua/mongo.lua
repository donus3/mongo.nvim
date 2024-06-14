local action = require("mongo.action")
local buffer = require("mongo.buffer")
local ss = require("mongo.session")

---@class Config
---@field default_url string the default connection string URL
---@field find_on_collection_selected boolean whether to auto query on collection selected
local config = {
  default_url = "mongodb://localhost:27017",
  find_on_collection_selected = false,
}

---@class MongoDB
local M = {}

---@type Config
M.config = config

---@param args Config?
-- you can define your setup function here. Usually configurations can be merged, accepting outside params and
-- you can also put some validation here for those.
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", M.config, args or {})
end

M.connect = function(args)
  local session = ss.new(args[1])
  action.init(M.config, session)
  action.connect(session)

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

return M
