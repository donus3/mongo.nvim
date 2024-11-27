local query = require("mongo.query")
local utils = require("mongo.util")
local buffer = require("mongo.buffer")
local client = require("mongo.client")
local ts = require("mongo.treesitter")

QueryAction = {}

---set_query_keymap sets the keymaps for query working space
---@param workspace Workspace
---@param database_name string
---@param collection_name string
---@param op "set" | "del"
local set_query_keymap = function(workspace, database_name, collection_name, op)
  local map = {
    {
      mode = "n",
      lhs = "<CR>",
      rhs = function()
        local queryWithInBeginEndScope = ts.getQueryInScope()
        if queryWithInBeginEndScope ~= nil then
          QueryAction.execute_asking(workspace, database_name, queryWithInBeginEndScope)
          return
        end

        local queries = utils.get_all_lines()
        QueryAction.execute_asking(workspace, database_name, queries)
      end,
      opts = { buffer = workspace.space.query.buf },
    },
    {
      mode = "n",
      lhs = "gf",
      rhs = function()
        query.find(workspace, collection_name)
      end,
      opts = { buffer = workspace.space.query.buf },
    },
    {
      mode = "n",
      lhs = "gi",
      rhs = function()
        query.insert_one(workspace, collection_name)
      end,
      opts = { buffer = workspace.space.query.buf },
    },
    {
      mode = "n",
      lhs = "gu",
      rhs = function()
        query.update_one(workspace, collection_name)
      end,
      opts = { buffer = workspace.space.query.buf },
    },
    {
      mode = "n",
      lhs = "gd",
      rhs = function()
        query.delete_one(workspace, collection_name)
      end,
      opts = { buffer = workspace.space.query.buf },
    },
  }
  utils.mapkeys(op, map)
end

---execute executes the query
---@param workspace Workspace
---@param queries string | string[]
---@param database_name string
---@param cb function
QueryAction.execute = function(workspace, database_name, queries, cb)
  local query_string = queries
  if type(queries) == "table" then
    query_string = table.concat(queries, " ")
  end

  client.run_async_command(workspace, database_name, query_string, function(out)
    if out.code ~= 0 then
      vim.defer_fn(function()
        vim.notify(out.stderr, vim.log.levels.ERROR)
      end, 0)
      return
    end

    local result = out.stdout:gsub("'", '"')

    if cb ~= nil then
      cb()
      return
    end

    vim.defer_fn(function()
      local text = {}
      if type(result) == "string" then
        text = vim.fn.split(result, "\n")
      end

      vim.api.nvim_set_option_value("modifiable", true, { buf = workspace.space.result.buf })
      buffer.show_result(workspace, text)
      vim.api.nvim_set_current_win(workspace.space.result.win)
      vim.api.nvim_set_option_value("modifiable", false, { buf = workspace.space.result.buf })
    end, 0)
  end)
end

---execute_asking executes the query
---@param workspace Workspace
---@param queries string[] | string
---@param database_name string
---@param cb function
QueryAction.execute_asking = function(workspace, database_name, queries, cb)
  vim.ui.input({ prompt = "Execute query?: [Y/n]" }, function(answer)
    if answer ~= "y" and answer ~= "Y" and answer ~= "" then
      return
    end

    QueryAction.execute(workspace, database_name, queries, cb)
  end)
end

---@param workspace Workspace
---@param database_name string
---@param collection_name string
QueryAction.init = function(workspace, database_name, collection_name)
  set_query_keymap(workspace, database_name, collection_name, "set")
end

return QueryAction
