local utils = require("mongo.util")
local ts = require("mongo.treesitter")
local query = require("mongo.query")

ResultAction = {}

---@param session Session
---@param op "set" | "del"
local set_result_keymap = function(session, op)
  local map = {
    {
      mode = "n",
      lhs = "e",
      rhs = function()
        local lines, id = ts.getDocument()
        if lines ~= nil then
          query.update_one(session, session.selected_collection, { lines, id })
          vim.api.nvim_set_current_win(session.query_win)
        end
      end,
      opts = { buffer = session.result_buf },
    },
    {
      mode = "n",
      lhs = "d",
      rhs = function()
        local _, id = ts.getDocument()
        if id ~= nil then
          query.delete_one(session, session.selected_collection, id)
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
