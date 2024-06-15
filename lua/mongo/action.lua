local buffer = require("mongo.buffer")
local query = require("mongo.query")
local constant = require("mongo.constant")
local utils = require("mongo.util")
local ts = require("mongo.treesitter")
local ss = require("mongo.session")

---@class Action
local Action = {}
Action.config = {}

table.unpack = table.unpack or unpack

Action.open_web = function()
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

---init initializes the action
---@param config Config
---@param session Session
Action.init = function(config, session)
  Action.config = config

  ss.set_url(session.name, Action.config.default_url)
  buffer.set_connection_win_content(session, { constant.host_example, "", session.url })
  buffer.create_command_buf(session)
  vim.api.nvim_set_current_win(session.connection_win)

  vim.cmd(":3")

  vim.keymap.set("n", "-", function()
    Action.back(session)
  end, { buffer = session.connection_buf })
  vim.keymap.set("n", "go", Action.open_web, { buffer = session.command_buf })

  for _, buf in ipairs({ session.connection_buf, session.command_buf }) do
    vim.keymap.set("n", "gq", function()
      buffer.clean(session)
    end, { buffer = buf })

    vim.keymap.set("n", "gs", fuzzy_session_search, { buffer = buf })
  end

  -- clean up autocmd when leave
  local group = vim.api.nvim_create_augroup("MongoDBActionLeave", { clear = true })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    buffer = session.command_buf,
    callback = function()
      ss.remove(session.name)
    end,
  })
end

---check_is_legacy_async check if the host is legacy or not
---@param session Session
---@param cb fun()
local check_is_legacy_async = function(session, cb)
  if session.is_legacy == nil then
    local host = ss.get_host(session.name)
    local full_cmd = {
      "mongosh",
      host,
      "--authenticationDatabase",
      session.auth_source,
      "--quiet",
    }

    vim.system(full_cmd, { text = true }, function(out)
      if out.stderr:find("MongoServerSelectionError") then
        ss.set_session_field(session.name, "is_legacy", true)
      else
        ss.set_session_field(session.name, "is_legacy", false)
      end
      cb()
    end)
  end
end

---run_command run mongosh or mongo with given args asynchronously
---@param session Session
---@param args string eval string arguments pass the mongosh
---@param on_exit fun(out: {code: number, stdout: string, stderr: string}) cb function to call after the command is done
local run_async_command = function(session, args, on_exit)
  vim.defer_fn(function()
    -- disable the back keymaps while running the command
    vim.keymap.set("n", "-", "", { buffer = session.connection_buf })
  end, 0)

  local host = ss.get_host(session.name)
  local cmd = "mongosh"
  if session.is_legacy then
    cmd = "mongo"
  end

  local full_cmd = {
    cmd,
    host .. "/" .. (session.selected_db or ""),
    "--authenticationDatabase",
    session.auth_source,
    "--quiet",
    "--eval",
    args,
  }

  if session.username ~= nil and session.password ~= nil then
    table.insert(full_cmd, "-u")
    table.insert(full_cmd, session.username)
    table.insert(full_cmd, "-p")
    table.insert(full_cmd, session.password)
  end

  return vim.system(full_cmd, { text = true }, function(out)
    print(vim.inspect(out))
    -- enable the back keymaps
    vim.defer_fn(function()
      vim.keymap.set("n", "-", function()
        Action.back(session)
      end, { buffer = session.connection_buf })
    end, 0)
    on_exit(out)
  end)
end

---selects the db name
---@param session Session
---@param skip_current_line boolean
local select_db = function(session, skip_current_line)
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

  Action.show_collections_async(workingSession)
end

---check the input mongo url and set each part to the corresponding module variable
---host, username, password, authSource, params
---@param session Session
local checkHost = function(session)
  local input_url = utils.get_line()

  ss.set_url(session.name, input_url)

  check_is_legacy_async(session, function()
    if session.selected_db ~= nil and session.selected_db ~= "" then
      select_db(session, true)
      return
    end

    Action.show_dbs_async(session)
  end)
end

---set_connect_keymaps sets the keymaps for connect
---@param session Session
---@param op "set" | "del"
Action.set_connect_keymaps = function(session, op)
  local map = {
    {
      mode = "n",
      lhs = "<CR>",
      rhs = function()
        checkHost(session)
      end,
      opts = { buffer = session.connection_buf },
    },
  }
  utils.mapkeys(op, map)
end

---connect connects to the given host
---@param session Session
Action.connect = function(session)
  ss.set_session_field(session.name, "current_state", constant.state.init)
  Action.set_connect_keymaps(session, "set")
end

---set_show_dbs_keymaps sets the keymaps for show dbs working space
---@param session Session
---@param op "set" | "del"
Action.set_show_dbs_keymaps = function(session, op)
  local map = {
    {
      mode = "n",
      lhs = "<CR>",
      rhs = function()
        select_db(session, false)
      end,
      opts = { buffer = session.connection_buf },
    },
  }
  utils.mapkeys(op, map)
end

---show_dbs_async shows the dbs
---@param session Session
Action.show_dbs_async = function(session)
  run_async_command(session, "db.getMongo().getDBNames()", function(out)
    if out.code ~= 0 then
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
          ss.set_session_field(session.name, "current_state", constant.state.connected)
          buffer.set_connection_win_content(session, { "/** DB List */", "No DB Found" })
        end, 0)
        return
      end

      vim.defer_fn(function()
        Action.set_show_dbs_keymaps(session, "set")
      end, 0)

      table.sort(dbs_filtered)

      ss.set_session_field(session.name, "dbs_filtered", dbs_filtered)
      vim.defer_fn(function()
        ss.set_session_field(session.name, "current_state", constant.state.connected)
        buffer.set_connection_win_content(session, { "/** DB List */", table.unpack(dbs_filtered) })
      end, 0)
      return
    end

    vim.defer_fn(function()
      ss.set_session_field(session.name, "current_state", constant.state.connected)
      buffer.set_connection_win_content(session, { "/** DB List */", "No DB Found" })
    end, 0)
  end)
end

---set_show_collections_keymap sets the keymaps for show collections working space
---@param session Session
---@param op "set" | "del"
Action.set_show_collections_keymap = function(session, op)
  local map = {
    {
      mode = "n",
      lhs = "<CR>",
      rhs = function()
        Action.select_collection(session)
      end,
      opts = { buffer = session.connection_buf },
    },
    {
      mode = "n",
      lhs = "gx",
      rhs = function()
        Action.execute_asking(session, string.format("db[%s].drop()", utils.get_line()))
        Action.show_collections_async(session)
      end,
      opts = { buffer = session.connection_buf },
    },
  }
  utils.mapkeys(op, map)
end

---show_collections_async shows the collections
---@param session Session
Action.show_collections_async = function(session)
  run_async_command(session, "db.getCollectionNames()", function(out)
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
        buffer.set_connection_win_content(session, { "/** Collection List */", table.unpack(collections_result) })
        Action.set_show_collections_keymap(session, "set")
        ss.set_session_field(session.name, "current_state", constant.state.db_selected)
      end, 0)

      return
    end

    vim.defer_fn(function()
      buffer.set_connection_win_content(session, { "/** Collection List */", "No Collection found" })
      ss.set_session_field(session.name, "current_state", constant.state.db_selected)
    end, 0)
  end)
end

---set_query_keymap sets the keymaps for query working space
---@param session Session
---@param op "set" | "del"
Action.set_query_keymap = function(session, op)
  local map = {
    {
      mode = "n",
      lhs = "<CR>",
      rhs = function()
        local queries = utils.get_all_lines()
        Action.execute_asking(session, queries)
      end,
      opts = { buffer = session.command_buf },
    },
    {
      mode = "n",
      lhs = "gf",
      rhs = function()
        query.find(session, session.selected_collection)
      end,
      opts = { buffer = session.command_buf },
    },
    {
      mode = "n",
      lhs = "gi",
      rhs = function()
        query.insert_one(session, session.selected_collection)
      end,
      opts = { buffer = session.command_buf },
    },
    {
      mode = "n",
      lhs = "gu",
      rhs = function()
        query.update_one(session, session.selected_collection)
      end,
      opts = { buffer = session.command_buf },
    },
    {
      mode = "n",
      lhs = "gd",
      rhs = function()
        query.delete_one(session, session.selected_collection)
      end,
      opts = { buffer = session.command_buf },
    },
  }
  utils.mapkeys(op, map)
end

---@param session Session
---@param op "set" | "del"
Action.set_result_keymap = function(session, op)
  local map = {
    {
      mode = "n",
      lhs = "e",
      rhs = function()
        local result = ts.getDocument()
        if result ~= nil then
          local to_update_object = {}
          for s in result:gmatch("[^\r\n]+") do
            table.insert(to_update_object, s)
          end
          query.update_one(session, session.selected_collection, to_update_object)
          vim.api.nvim_set_current_win(session.command_win)
        end
      end,
      opts = { buffer = session.result_buf },
    },
    {
      mode = "n",
      lhs = "d",
      rhs = function()
        local result = ts.getDocument()
        if result ~= nil then
          local to_update_object = {}
          for s in result:gmatch("[^\r\n]+") do
            table.insert(to_update_object, s)
          end
          query.delete_one(session, session.selected_collection, to_update_object)
          vim.api.nvim_set_current_win(session.command_win)
        end
      end,
      opts = { buffer = session.result_buf },
    },
  }
  utils.mapkeys(op, map)

  vim.keymap.set("n", "gq", function()
    buffer.clean(session)
  end, { buffer = session.result_buf })

  vim.keymap.set("n", "gs", fuzzy_session_search, { buffer = session.result_buf })
end

---@param session Session
Action.select_collection = function(session)
  ss.set_session_field(session.name, "selected_collection", utils.get_line())

  query.find(session, session.selected_collection)
  vim.api.nvim_set_current_win(session.command_win)
  if Action.config.find_on_collection_selected then
    Action.execute_query_fn(query.find, session.selected_collection)
  end

  Action.set_query_keymap(session, "set")
  ss.set_session_field(session.name, "current_state", constant.state.collection_selected)
  vim.defer_fn(function() end, 0)
end

---execute executes the query
----@param session Session
----@param queries string
Action.execute = function(session, queries)
  local query_string = queries
  if type(queries) == "table" then
    query_string = table.concat(queries, " ")
  end

  run_async_command(session, query_string, function(out)
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

      buffer.create_result_buf(session)
      Action.set_result_keymap(session, "set")
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
Action.execute_asking = function(session, queries)
  vim.ui.input({ prompt = "Execute query?: [Y/n]" }, function(answer)
    if answer ~= "y" and answer ~= "Y" and answer ~= "" then
      return
    end

    Action.execute(session, queries)
  end)
end

---execute_query_fn executes the query
----@param session Session
----@param queryFunction fun(args: string)
----@param args string
Action.execute_query_fn = function(session, queryFunction, args)
  queryFunction(args)
  local queries = utils.get_all_lines()
  Action.execute(session, queries)
end

---back go back to the previous state
---@param session Session
Action.back = function(session)
  if session.current_state == constant.state.collection_selected then
    Action.set_query_keymap(session, "del")
    ss.set_session_field(session.name, "current_state", constant.state.db_selected)
    ss.set_session_field(session.name, "selected_collection", "")
    ss.set_session_field(session.name, "collections", {})
    buffer.delete_result_win(session)
    buffer.set_command_content(session, {})
    Action.show_collections_async(session)
  elseif session.current_state == constant.state.db_selected then
    Action.set_show_collections_keymap(session, "del")
    ss.set_session_field(session.name, "current_state", constant.state.connected)
    ss.set_session_field(session.name, "dbs_filtered", {})
    ss.set_session_field(session.name, "selected_db", "")
    Action.show_dbs_async(session)
  elseif session.current_state == constant.state.connected then
    Action.set_show_dbs_keymaps(session, "del")
    ss.set_session_field(session.name, "current_state", constant.state.init)
    ss.set_session_field(session.name, "is_legacy", false)
    buffer.set_connection_win_content(session, { constant.host_example, "", session.url })
    Action.set_connect_keymaps(session, "set")
  end
end

return Action
