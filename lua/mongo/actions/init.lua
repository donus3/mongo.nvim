local connection = require("mongo.actions.connection")
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

---@param workspace Workspace
Action.init = function(workspace)
  buffer.set_connection_content(workspace, { constant.host_example, "", workspace.connection.uri })
  vim.cmd(":3")

  vim.keymap.set("n", "go", open_web, { buffer = workspace.space.query.buf })

  connection.init(workspace)
  database.init(workspace)
end

return Action
