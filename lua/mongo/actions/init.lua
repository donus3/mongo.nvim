local connection = require("mongo.actions.connection")
local collection = require("mongo.actions.collection")
local result = require("mongo.actions.result")
local query = require("mongo.actions.query")
local constant = require("mongo.constant")
local ss = require("mongo.session")
local buffer = require("mongo.buffer")
local database = require("mongo.actions.database")

---@class Action
local Action = {}

table.unpack = table.unpack or unpack

local open_web = function()
  vim.fn.system({ "open", constant.mongodb_crud_page })
end

local fuzzy_session_search = function()
  require("fzf-lua").fzf_exec(ss.list_names(), {
    prompt = "Session name> ",
    winopts = { height = 0.33, width = 0.66 },
    complete = function(selected)
      vim.api.nvim_set_current_tabpage(ss.get(selected[1]).tabpage_num)
    end,
  })
end

---@param session Session
Action.init = function(session)
  ss.set_url(session.name, session.config.default_url)
  buffer.set_connection_content(session, { constant.host_example, "", session.url })
  vim.cmd(":3")

  vim.keymap.set("n", "go", open_web, { buffer = session.query_buf })

  for _, buf in ipairs({
    session.connection_buf,
    session.query_buf,
    session.result_buf,
    session.collection_buf,
    session.database_buf,
  }) do
    vim.keymap.set("n", "gq", function()
      buffer.clean(session)
    end, { buffer = buf })

    vim.keymap.set("n", "gs", fuzzy_session_search, { buffer = buf })
  end

  connection.init(session)
  collection.init(session)
  database.init(session)
  result.init(session)
  query.init(session)
end

return Action
