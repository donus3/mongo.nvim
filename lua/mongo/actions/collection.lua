local utils = require("mongo.util")
local buffer = require("mongo.buffer")
local query = require("mongo.query")
local query_actions = require("mongo.actions.query")
local result_actions = require("mongo.actions.result")
local client = require("mongo.client")

Collection_actions = {}

---@param workspace Workspace
---@param collection Collection
---@param database_name string
Collection_actions.select_collection = function(workspace, collection, database_name)
  query.find(workspace, collection.name)
  vim.api.nvim_set_current_win(workspace.space.query.win)

  query_actions.init(workspace, database_name, collection.name)
  result_actions.init(workspace, collection.name)
end

---show_collections_async shows the collections
---@param workspace Workspace
---@param database Database
Collection_actions.show_collections_async = function(workspace, database)
  client.run_async_command(workspace, database.name, "db.getCollectionNames()", function(out)
    if out.code ~= 0 then
      vim.defer_fn(function()
        vim.notify(out.stderr, vim.log.levels.ERROR)
      end, 0)
      return
    end

    vim.defer_fn(function()
      database:set_collections_from_raw_string(workspace, out.stdout)

      local lines = workspace:draw_tree()
      buffer.set_database_content(workspace, lines)
    end, 0)
  end)
end

return Collection_actions
