local utils = require("mongo.util")
local ss = require("mongo.session")
local collection = require("mongo.actions.collection")
local client = require("mongo.client")
local buffer = require("mongo.buffer")

local DB = {}

---selects the db name
---@param session Session
---@param skip_current_line boolean
DB.select_db = function(session, skip_current_line)
  if not skip_current_line then
    ss.set_session_field(session.name, "selected_db", utils.get_line())
  end

  local workingSession = session
  if session.name:match("^temp__.*") then
    local db_name = session.selected_db
    if db_name ~= nil then
      ss.renameSession(session.name, db_name)
      workingSession = ss.get(db_name)
    end
  end

  collection.show_collections_async(workingSession)
end

---show_dbs_async shows the dbs
---@param session Session
DB.show_dbs_async = function(session)
  client.run_async_command(session, "db.getMongo().getDBNames()", function(out)
    if out.code ~= 0 then
      ss.set_url(session.name, "")
      vim.defer_fn(function()
        vim.notify(out.stderr, vim.log.levels.ERROR)
      end, 0)
      return
    end

    local dbs = out.stdout:gsub("'", '"')
    ss.set_session_field(session.name, "dbs_filtered", {})
    if dbs ~= nil then
      if dbs:match("^Mongo") then
        vim.defer_fn(function()
          vim.notify(dbs, vim.log.levels.WARN)
        end, 0)
        return
      end

      local dbs_filtered = {}
      for _, d in ipairs(vim.json.decode(dbs)) do
        table.insert(dbs_filtered, d)
      end

      if next(dbs_filtered) == nil then
        vim.defer_fn(function()
          buffer.set_database_content(session, { "/** DB List */", "No DB Found" })
        end, 0)
        return
      end

      table.sort(dbs_filtered)

      ss.set_session_field(session.name, "dbs_filtered", dbs_filtered)
      vim.defer_fn(function()
        buffer.set_database_content(session, { "/** DB List */", table.unpack(dbs_filtered) })
        vim.api.nvim_set_current_win(session.database_win)
      end, 0)
      return
    end

    vim.defer_fn(function()
      buffer.set_database_content(session, { "/** DB List */", "No DB Found" })
    end, 0)
  end)
end

---set_show_dbs_keymaps sets the keymaps for show dbs working space
---@param session Session
---@param op "set" | "del"
local set_show_dbs_keymaps = function(session, op)
  local map = {
    {
      mode = "n",
      lhs = "<CR>",
      rhs = function()
        DB.select_db(session, false)
      end,
      opts = { buffer = session.database_buf },
    },
    {
      mode = "n",
      lhs = "<c-r>",
      rhs = function()
        DB.show_dbs_async(session)
      end,
      opts = { buffer = session.database_buf },
    },
  }
  utils.mapkeys(op, map)
end

---@param session Session
DB.init = function(session)
  set_show_dbs_keymaps(session, "set")
end

return DB
