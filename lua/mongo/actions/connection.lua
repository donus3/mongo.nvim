local ss = require("mongo.session")
local client = require("mongo.client")
local db = require("mongo.actions.database")
local utils = require("mongo.util")

local Connection = {}

---check the input mongo url and set each part to the corresponding module variable
---host, username, password, authSource, params
---@param session Session
local checkHost = function(session)
  local input_url = utils.get_line()

  ss.set_url(session.name, input_url)

  client.check_is_legacy_async(session, function()
    if session.selected_db ~= nil and session.selected_db ~= "" then
      db.select_db(session, true)
      return
    end

    db.show_dbs_async(session)
  end)
end

---set_connect_keymaps sets the keymaps for connect
---@param session Session
---@param op "set" | "del"
local set_connect_keymaps = function(session, op)
  local map = {
    {
      mode = "n",
      lhs = "<CR>",
      rhs = function()
        checkHost(session)
      end,
      opts = { buffer = session.connection_buf },
    },
  }
  utils.mapkeys(op, map)
end

---@param session Session
Connection.init = function(session)
  set_connect_keymaps(session, "set")
end

return Connection
