local utils = require("mongo.util")
local client = require("mongo.client")
local buffer = require("mongo.buffer")
local query_action = require("mongo.actions.query")
local collection_actions = require("mongo.actions.collection")
local spinner = require("mongo.utils.spinner")
local tree_ui = require("mongo.ui.tree")
local constant = require("mongo.constant")

local DB = {}

---show_dbs_async shows the dbs
---@param workspace Workspace
DB.show_dbs_async = function(workspace)
  local connection = workspace.connection
  spinner.start_spinner(workspace.space.database.buf)
  client.run_async_command(workspace, "", "db.getMongo().getDBNames()", function(out)
    if out.code ~= 0 then
      vim.defer_fn(function()
        spinner.stop_spinner(utils.string_to_table_lines(out.stderr))
        vim.notify(out.stderr, vim.log.levels.ERROR)
      end, 0)
      return
    end

    vim.defer_fn(function()
      spinner.stop_spinner()
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
        local selected_item_name = utils.get_line()

        -- build a new tree to ensure if there is a new item added
        -- and then set the new tree back to the workspace
        workspace.tree = tree_ui.build_tree_from_strings(utils.get_all_lines(), function(database_node)
          return function()
            collection_actions.show_collections_async(workspace, database_node)
          end
        end, function(database_node, collection_node)
          return function()
            vim.api.nvim_buf_set_name(
              workspace.space.query.buf,
              constant.workspace .. workspace.name .. constant.query_buf_name .. database_node.value.name
            )
            Collection_actions.select_collection(workspace, collection_node, database_node.value.name)
          end
        end)
        local result = workspace.tree:draw(nil, 0, {})

        -- find node to get handler function and execute
        local target_row = utils.find_in_array(result, selected_item_name)
        if target_row ~= nil then
          target_row.is_expanded = not target_row.is_expanded
          if target_row.handler ~= nil then
            target_row.handler()
          end
        end
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
