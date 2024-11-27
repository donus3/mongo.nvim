local utils = require("mongo.util")
local ts = require("mongo.treesitter")
local query = require("mongo.query")

ResultAction = {}

---@param workspace Workspace
---@param collection_name string
---@param op "set" | "del"
local set_result_keymap = function(workspace, collection_name, op)
  local map = {
    {
      mode = "n",
      lhs = "e",
      rhs = function()
        local lines, id = ts.getDocument()
        if lines ~= nil then
          query.update_one(workspace, collection_name, { lines, id })
          vim.api.nvim_set_current_win(workspace.space.query.win)
        end
      end,
      opts = { buffer = workspace.space.result.buf },
    },
    {
      mode = "n",
      lhs = "d",
      rhs = function()
        local _, id = ts.getDocument()
        if id ~= nil then
          query.delete_one(workspace, collection_name, id)
          vim.api.nvim_set_current_win(workspace.space.query.win)
        end
      end,
      opts = { buffer = workspace.space.result.buf },
    },
  }
  utils.mapkeys(op, map)
end

---@param workspace Workspace
ResultAction.init = function(workspace, collection_name)
  set_result_keymap(workspace, collection_name, "set")
end

return ResultAction
