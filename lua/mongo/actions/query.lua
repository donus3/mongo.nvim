local query = require("mongo.query")
local utils = require("mongo.util")
local buffer = require("mongo.buffer")
local client = require("mongo.client")

QueryAction = {}

---set_query_keymap sets the keymaps for query working space
---@param session Session
---@param op "set" | "del"
local set_query_keymap = function(session, op)
  local map = {
    {
      mode = "n",
      lhs = "<CR>",
      rhs = function()
        local queries = utils.get_all_lines()
        QueryAction.execute_asking(session, queries)
      end,
      opts = { buffer = session.query_buf },
    },
    {
      mode = "n",
      lhs = "gf",
      rhs = function()
        query.find(session, session.selected_collection)
      end,
      opts = { buffer = session.query_buf },
    },
    {
      mode = "n",
      lhs = "gi",
      rhs = function()
        query.insert_one(session, session.selected_collection)
      end,
      opts = { buffer = session.query_buf },
    },
    {
      mode = "n",
      lhs = "gu",
      rhs = function()
        query.update_one(session, session.selected_collection)
      end,
      opts = { buffer = session.query_buf },
    },
    {
      mode = "n",
      lhs = "gd",
      rhs = function()
        query.delete_one(session, session.selected_collection)
      end,
      opts = { buffer = session.query_buf },
    },
  }
  utils.mapkeys(op, map)
end

---execute executes the query
----@param session Session
----@param queries string
QueryAction.execute = function(session, queries)
  local query_string = queries
  if type(queries) == "table" then
    query_string = table.concat(queries, " ")
  end

  client.run_async_command(session, query_string, function(out)
    if out.code ~= 0 then
      vim.defer_fn(function()
        vim.notify(out.stderr, vim.log.levels.ERROR)
      end, 0)
      return
    end

    local result = out.stdout:gsub("'", '"')

    local text = {}
    vim.defer_fn(function()
      if type(result) == "string" then
        text = vim.fn.split(result, "\n")
      end

      vim.api.nvim_set_option_value("modifiable", true, { buf = session.result_buf })
      buffer.show_result(session, text)
      vim.api.nvim_set_current_win(session.result_win)
      vim.api.nvim_set_option_value("modifiable", false, { buf = session.result_buf })
    end, 0)
  end)
end

---execute_asking executes the query
-----@param session Session
-----@param queries string
QueryAction.execute_asking = function(session, queries)
  vim.ui.input({ prompt = "Execute query?: [Y/n]" }, function(answer)
    if answer ~= "y" and answer ~= "Y" and answer ~= "" then
      return
    end

    QueryAction.execute(session, queries)
  end)
end

---execute_query_fn executes the query
----@param session Session
----@param queryFunction fun(args: string)
----@param args string
QueryAction.execute_query_fn = function(session, queryFunction, args)
  queryFunction(args)
  local queries = utils.get_all_lines()
  QueryAction.execute(session, queries)
end

---@param session Session
QueryAction.init = function(session)
  set_query_keymap(session, "set")
end

return QueryAction
