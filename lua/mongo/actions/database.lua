local utils = require("mongo.util")
local client = require("mongo.client")
local buffer = require("mongo.buffer")
local query_action = require("mongo.actions.query")
local constant = require("mongo.constant")

local DB = {}

---show_dbs_async shows the dbs
---@param workspace Workspace
DB.show_dbs_async = function(workspace)
  local connection = workspace.connection
  client.run_async_command(workspace, "", "db.getMongo().getDBNames()", function(out)
    if out.code ~= 0 then
      vim.defer_fn(function()
        vim.notify(out.stderr, vim.log.levels.ERROR)
      end, 0)
      return
    end

    vim.defer_fn(function()
      connection:set_db_from_raw_string(workspace, out.stdout)

      local lines = workspace:draw_tree()
      buffer.set_database_content(workspace, lines)
      vim.api.nvim_set_current_win(workspace.space.database.win)
    end, 0)
  end)
end

---set_show_dbs_keymaps sets the keymaps for show dbs working space
---@param workspace Workspace
---@param op "set" | "del"
local set_show_dbs_keymaps = function(workspace, op)
  local map = {
    {
      mode = "n",
      lhs = "<CR>",
      rhs = function()
        local row = unpack(vim.api.nvim_win_get_cursor(0))
        local line = utils.get_line()
        local result = workspace.tree:draw(nil, 0, {})
        --- new node
        if result[row].display == line then
          if result[row].handler ~= nil then
            result[row].handler()
          end
        else
          local above_line = ""
          local node_type = "Database"
          if row > 1 then
            above_line = unpack(vim.api.nvim_buf_get_lines(0, row - 2, row - 1, false))
            vim.print("above_line: " .. above_line)
            node_type = above_line:find("^  ") and "Collection" or "Database"
          end

          local normalized_line = line:gsub("[%s]+", "")
          local normalized_above_line = above_line:gsub("[%s]+", "")
          local result_node = workspace.tree:find_node(normalized_above_line, node_type)
          if result_node.target == nil then
            vim.print(normalized_line .. ": " .. node_type)
            vim.notify("Node not found", vim.log.levels.ERROR)
            return
          end

          local collection = Collection:new(normalized_line)
          local target_node = result_node.target
          if target_node == nil then
            return
          end

          if node_type == "Collection" then
            target_node = result_node.root
          end
          target_node:add_child(Node:new(collection, false, function()
            vim.api.nvim_buf_set_name(
              workspace.space.query.buf,
              constant.workspace .. workspace.name .. constant.query_buf_name .. target_node.value.name
            )
            Collection_actions.select_collection(workspace, collection, normalized_line)
          end))
          Collection_actions.select_collection(workspace, collection, normalized_line)
        end

        local lines = workspace:draw_tree()
        buffer.set_database_content(workspace, lines)
      end,
      opts = { buffer = workspace.space.database.buf },
    },
    {
      mode = "n",
      lhs = "gx",
      rhs = function()
        local line = utils.get_line()
        local normalized_line = line:gsub("[%s]+", "")
        local result = workspace.tree:find_node(normalized_line, "Collection")
        query_action.execute_asking(
          workspace,
          result.root.value.name,
          string.format("db['%s'].drop()", normalized_line),
          function()
            DB.show_dbs_async(workspace)
          end
        )
      end,
      opts = { buffer = workspace.space.database.buf },
    },
    {
      mode = "n",
      lhs = "<c-r>",
      rhs = function()
        DB.show_dbs_async(workspace)
      end,
      opts = { buffer = workspace.space.database.buf },
    },
  }
  utils.mapkeys(op, map)
end

---@param workspace Workspace
DB.init = function(workspace)
  set_show_dbs_keymaps(workspace, "set")
end

return DB
