local utils = require("mongo.util")
local ts = require("mongo.treesitter")
local query = require("mongo.query")
local buffer = require("mongo.buffer")

ResultAction = {}

---@param session Session
---@param op "set" | "del"
local set_result_keymap = function(session, op)
  local map = {
    {
      mode = "n",
      lhs = "e",
      rhs = function()
        local result = ts.getDocument()
        if result ~= nil then
          local to_update_object = {}
          for s in result:gmatch("[^\r\n]+") do
            table.insert(to_update_object, s)
          end
          query.update_one(session, session.selected_collection, to_update_object)
          vim.api.nvim_set_current_win(session.query_win)
        end
      end,
      opts = { buffer = session.result_buf },
    },
    {
      mode = "n",
      lhs = "d",
      rhs = function()
        local result = ts.getDocument()
        if result ~= nil then
          local to_update_object = {}
          for s in result:gmatch("[^\r\n]+") do
            table.insert(to_update_object, s)
          end
          query.delete_one(session, session.selected_collection, to_update_object)
          vim.api.nvim_set_current_win(session.query_win)
        end
      end,
      opts = { buffer = session.result_buf },
    },
  }
  utils.mapkeys(op, map)
end

---@param session Session
ResultAction.init = function(session)
  set_result_keymap(session, "set")
end

return ResultAction
