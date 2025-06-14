local connection = require("mongo.actions.connection")
local constant = require("mongo.constant")
local buffer = require("mongo.buffer")
local database = require("mongo.actions.database")

---@class Action
local Action = {}

table.unpack = table.unpack or unpack

local open_web = function()
  vim.fn.system({ "open", constant.mongodb_crud_page })
end

---@param workspace Workspace
Action.init = function(workspace)
  buffer.set_connection_content(workspace, { constant.host_example, "", workspace.connection.uri })
  vim.cmd(":3")

  vim.keymap.set("n", "go", open_web, { buffer = workspace.space.query.buf })

  connection.init(workspace)
  database.init(workspace)
end

return Action
