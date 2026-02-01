local client = require("mongo.client")
local db = require("mongo.actions.database")
local utils = require("mongo.util")

local Connection = {}

---check the input mongo url and set each part to the corresponding module variable
---host, username, password, authSource, params
---@param workspace Workspace
local connect = function(workspace)
  local input_url = utils.get_line()
  local connection = workspace.connection

  connection:set_uri(input_url)

  client.check_is_legacy_async(workspace, function(is_legacy)
    connection.is_legacy = is_legacy
    db.show_dbs_async(workspace)
  end)
end

---set_connect_keymaps sets the keymaps for connect
---@param workspace Workspace
---@param op "set" | "del"
local set_connect_keymaps = function(workspace, op)
  local map = {
    {
      mode = "n",
      lhs = "<CR>",
      rhs = function()
        connect(workspace)
      end,
      opts = { buffer = workspace.space.connection.buf },
    },
  }
  utils.mapkeys(op, map)
end

---@param workspace Workspace
Connection.init = function(workspace)
  set_connect_keymaps(workspace, "set")
end

return Connection
