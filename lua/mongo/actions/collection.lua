local utils = require("mongo.util")
local buffer = require("mongo.buffer")
local ss = require("mongo.session")
local query = require("mongo.query")
local client = require("mongo.client")

Collection = {}

---@param session Session
Collection.select_collection = function(session)
  ss.set_session_field(session.name, "selected_collection", utils.get_line())

  query.find(session, session.selected_collection)
  vim.api.nvim_set_current_win(session.query_win)
  if session.config.find_on_collection_selected then
    Collection.execute_query_fn(query.find, session.selected_collection)
  end
end

---show_collections_async shows the collections
---@param session Session
Collection.show_collections_async = function(session)
  client.run_async_command(session, "db.getCollectionNames()", function(out)
    if out.code ~= 0 then
      vim.defer_fn(function()
        vim.notify(out.stderr, vim.log.levels.ERROR)
      end, 0)
      return
    end

    local collections_result = {}
    if out.stdout ~= nil then
      local collections = out.stdout:gsub("'", '"')
      if collections:match("^Mongo") then
        vim.defer_fn(function()
          vim.notify(collections, vim.log.levels.WARN)
        end, 0)
        return
      end
      collections_result = vim.json.decode(collections)

      table.sort(collections_result)
      ss.set_session_field(session.name, "collections", collections_result)

      vim.defer_fn(function()
        buffer.set_collection_content(session, { "/** Collection List */", table.unpack(collections_result) })
        vim.api.nvim_set_current_win(session.collection_win)
      end, 0)

      return
    end

    vim.defer_fn(function()
      buffer.set_collection_content(session, { "/** Collection List */", "No Collection found" })
    end, 0)
  end)
end

---set_collections_keymap sets the keymaps for collections working space
---@param session Session
---@param op "set" | "del"
local set_collections_keymap = function(session, op)
  local map = {
    {
      mode = "n",
      lhs = "<CR>",
      rhs = function()
        Collection.select_collection(session)
      end,
      opts = { buffer = session.collection_buf },
    },
    {
      mode = "n",
      lhs = "gx",
      rhs = function()
        Collection.execute_asking(session, string.format("db[%s].drop()", utils.get_line()))
        Collection.show_collections_async(session)
      end,
      opts = { buffer = session.collection_buf },
    },
  }
  utils.mapkeys(op, map)
end

---@param session Session
Collection.init = function(session)
  set_collections_keymap(session, "set")
end

return Collection
