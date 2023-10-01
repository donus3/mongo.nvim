local buffer = require("mongo.buffer")
local query = require("mongo.query")
local constant = require("mongo.constant")
local utils = require("mongo.util")
local ts = require("mongo.treesitter")

---@class Action
local M = {}
M.dbs_filtered = {}
M.collections = {}
M.selected_db = nil
M.selected_collection = ""
M.username = nil
M.password = nil
M.authSource = "admin"
M.host = nil
M.url = constant.host_fallback
M.params = nil
---state machine
---init -> connected -> db_selected -> collection_selected
M.current_state = constant.state.init
M.is_legacy = nil
M.config = {}

table.unpack = table.unpack or unpack

local clean = function()
  M.dbs_filtered = {}
  M.collections = {}
  M.selected_db = nil
  M.selected_collection = ""
  M.username = nil
  M.password = nil
  M.authSource = "admin"
  M.host = nil
  M.url = constant.host_fallback
  M.params = nil
  M.current_state = constant.state.init
  M.is_legacy = nil
end

M.open_web = function()
  vim.fn.system({ "open", constant.mongodb_crud_page })
end

M.init = function(config)
  clean()
  M.config = config

  M.url = M.config.default_url or M.url
  buffer.set_connection_win_content({ constant.host_example, "", M.url })
  buffer.create_command_buf()
  vim.api.nvim_set_current_win(buffer.connection_win)

  vim.cmd(":3")

  vim.keymap.set("n", "-", M.back, { buffer = buffer.connection_buf })
  vim.keymap.set("n", "go", M.open_web, { buffer = buffer.command_buf })
  vim.keymap.set("n", "gq", buffer.clean, { buffer = buffer.connection_buf })
  vim.keymap.set("n", "gq", buffer.clean, { buffer = buffer.command_buf })
  vim.keymap.set("n", "gq", buffer.clean, { buffer = buffer.result_buf })

  -- clean up autocmd when leave
  local group = vim.api.nvim_create_augroup("MongoDBActionLeave", { clear = true })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    buffer = buffer.command_buf,
    callback = function()
      clean()
    end,
  })
end

local get_host = function()
  local host = M.host

  if M.selected_db ~= nil then
    host = host .. "/" .. M.selected_db
  end

  if M.params ~= nil then
    host = host .. "/" .. M.params
  end

  return host
end

local check_is_legacy_async = function(cb)
  if M.is_legacy == nil then
    local host = get_host()
    local full_cmd = {
      "mongosh",
      host,
      "--authenticationDatabase",
      M.authSource,
      "--quiet",
    }

    vim.system(full_cmd, { text = true }, function(out)
      if out.stderr:find("MongoServerSelectionError") then
        M.is_legacy = true
      else
        M.is_legacy = false
      end
      cb()
    end)
  end
end

---run_command run mongosh or mongo with given args asynchronously
---@param args string eval string arguments pass the mongosh
---@param on_exit fun(out: {code: number, stdout: string, stderr: string}) cb function to call after the command is done
local run_async_command = function(args, on_exit)
  vim.defer_fn(function()
    -- disable the back keymaps while running the command
    vim.keymap.set("n", "-", "", { buffer = buffer.connection_buf })
  end, 0)

  local host = get_host()
  local cmd = "mongosh"
  if M.is_legacy then
    cmd = "mongo"
  end

  local full_cmd = {
    cmd,
    host,
    "--authenticationDatabase",
    M.authSource,
    "--quiet",
    "--eval",
    args,
  }

  if M.username ~= nil and M.password ~= nil then
    table.insert(full_cmd, "-u")
    table.insert(full_cmd, M.username)
    table.insert(full_cmd, "-p")
    table.insert(full_cmd, M.password)
  end

  return vim.system(full_cmd, { text = true }, function(out)
    -- enable the back keymaps
    vim.defer_fn(function()
      vim.keymap.set("n", "-", M.back, { buffer = buffer.connection_buf })
    end, 0)
    on_exit(out)
  end)
end

local setParams = function(params, options)
  if params ~= nil then
    for authSource in params:gmatch("[&]?auth[S|s]ource=(%w+)[&]?") do
      if authSource ~= nil then
        M.authSource = authSource
      end
    end
    local excludeAuthSourceOptions = options:gsub("[&]?authSource=%w+[&]?", "")
    if excludeAuthSourceOptions ~= nil and excludeAuthSourceOptions ~= "?" then
      M.params = excludeAuthSourceOptions
    end
  end
end

local check_options = function(input_url, options)
  if options ~= nil then
    if options:match("^%?.*$") == nil then
      -- there is a db name in the URL
      for db_name, params in input_url:gmatch("(%w+)(/%?.*)$") do
        M.selected_db = db_name
        setParams(params, options)
      end
    else
      setParams(options, options)
    end
  end
end

local select_db = function(skip_current_line)
  if not skip_current_line then
    M.selected_db = utils.get_line()
  end
  M.show_collections_async()
end

-- check the input mongo url and set each part to the corresponding module variable
-- host, username, password, authSource, params
local checkHost = function()
  local input_url = utils.get_line()

  M.url = input_url
  -- try to parse the url with username and password
  for username, password, host, options in input_url:gmatch("mongodb://(.*):(.*)@([%w|:|%d]+[/]?%w*)[/]?(.*)$") do
    M.username = username
    M.password = password
    M.host = host
    check_options(input_url, options)
  end

  if M.host == nil then
    -- try to parse the url without username and password
    for host, options in input_url:gmatch("mongodb://([%w|:|%d]+)[/]?(.*)$") do
      M.host = host
      check_options(input_url, options)
    end
  end

  if M.host == nil then
    vim.notify(
      "Unsupported mongodb URL "
        .. input_url
        .. ". Please use mongodb://username:password@host[/db_name][/?options] or mongodb://host[/db_name][/?options]",
      vim.log.levels.ERROR
    )
  end

  for host, db_name in M.host:gmatch("(.*)/(.*)") do
    if db_name ~= nil then
      M.host = host
      M.selected_db = db_name
    end
  end

  check_is_legacy_async(function()
    if M.selected_db ~= nil and M.selected_db ~= "" then
      select_db(true)
      return
    end

    M.show_dbs_async()
  end)
end

---set_connect_keymaps sets the keymaps for connect
---@param op "set" | "del"
M.set_connect_keymaps = function(op)
  local map = {
    {
      mode = "n",
      lhs = "<CR>",
      rhs = checkHost,
      opts = { buffer = buffer.connection_buf },
    },
  }
  utils.mapkeys(op, map)
end

---connect connects to the given host
M.connect = function()
  M.current_state = constant.state.init
  M.set_connect_keymaps("set")
end

---set_show_dbs_keymaps sets the keymaps for show dbs working space
---@param op "set" | "del"
M.set_show_dbs_keymaps = function(op)
  local map = {
    {
      mode = "n",
      lhs = "<CR>",
      rhs = select_db,
      opts = { buffer = buffer.connection_buf },
    },
  }
  utils.mapkeys(op, map)
end

M.show_dbs_async = function()
  run_async_command("db.getMongo().getDBNames()", function(out)
    if out.code ~= 0 then
      clean()
      vim.defer_fn(function()
        vim.notify(out.stderr, vim.log.levels.ERROR)
      end, 0)
      return
    end

    local dbs = out.stdout:gsub("'", '"')
    M.dbs_filtered = {}
    if dbs ~= nil then
      if dbs:match("^Mongo") then
        vim.defer_fn(function()
          vim.notify(dbs, vim.log.levels.WARN)
        end, 0)
        return
      end

      for _, d in ipairs(vim.json.decode(dbs)) do
        table.insert(M.dbs_filtered, d)
      end

      if next(M.dbs_filtered) == nil then
        vim.defer_fn(function()
          M.current_state = constant.state.connected
          buffer.set_connection_win_content({ "/** DB List */", "No DB Found" })
        end, 0)
        return
      end

      vim.defer_fn(function()
        M.set_show_dbs_keymaps("set")
      end, 0)

      table.sort(M.dbs_filtered)

      vim.defer_fn(function()
        M.current_state = constant.state.connected
        buffer.set_connection_win_content({ "/** DB List */", table.unpack(M.dbs_filtered) })
      end, 0)
      return
    end

    vim.defer_fn(function()
      M.current_state = constant.state.connected
      buffer.set_connection_win_content({ "/** DB List */", "No DB Found" })
    end, 0)
  end)
end

---set_show_collections_keymap sets the keymaps for show collections working space
---@param op "set" | "del"
M.set_show_collections_keymap = function(op)
  local map = {
    {
      mode = "n",
      lhs = "<CR>",
      rhs = M.select_collection,
      opts = { buffer = buffer.connection_buf },
    },
    {
      mode = "n",
      lhs = "gx",
      rhs = function()
        M.execute_asking(string.format("db[%s].drop()", utils.get_line()))
        M.show_collections_async()
      end,
      opts = { buffer = buffer.connection_buf },
    },
  }
  utils.mapkeys(op, map)
end

M.show_collections_async = function()
  run_async_command("db.getCollectionNames()", function(out)
    if out.code ~= 0 then
      vim.defer_fn(function()
        vim.notify(out.stderr, vim.log.levels.ERROR)
      end, 0)
      return
    end

    M.collections = {}
    local collections = out.stdout:gsub("'", '"')
    if collections ~= nil then
      if collections:match("^Mongo") then
        vim.defer_fn(function()
          vim.notify(collections, vim.log.levels.WARN)
        end, 0)
        return
      end
      M.collections = vim.json.decode(collections)

      table.sort(M.collections)
      vim.defer_fn(function()
        buffer.set_connection_win_content({ "/** Collection List */", table.unpack(M.collections) })
        M.set_show_collections_keymap("set")
        M.current_state = constant.state.db_selected
      end, 0)

      return
    end

    vim.defer_fn(function()
      buffer.set_connection_win_content({ "/** Collection List */", "No Collection found" })
      M.current_state = constant.state.db_selected
    end, 0)
  end)
end

---set_query_keymap sets the keymaps for query working space
---@param op "set" | "del"
M.set_query_keymap = function(op)
  local map = {
    {
      mode = "n",
      lhs = "<CR>",
      rhs = function()
        local queries = utils.get_all_lines()
        M.execute_asking(queries)
      end,
      opts = { buffer = buffer.command_buf },
    },
    {
      mode = "n",
      lhs = "gf",
      rhs = function()
        query.find(M.selected_collection)
      end,
      opts = { buffer = buffer.command_buf },
    },
    {
      mode = "n",
      lhs = "gi",
      rhs = function()
        query.insert_one(M.selected_collection)
      end,
      opts = { buffer = buffer.command_buf },
    },
    {
      mode = "n",
      lhs = "gu",
      rhs = function()
        query.update_one(M.selected_collection)
      end,
      opts = { buffer = buffer.command_buf },
    },
    {
      mode = "n",
      lhs = "gd",
      rhs = function()
        query.delete_one(M.selected_collection)
      end,
      opts = { buffer = buffer.command_buf },
    },
  }
  utils.mapkeys(op, map)
end

M.set_result_keymap = function(op)
  local map = {
    {
      mode = "n",
      lhs = "e",
      rhs = function()
        local result = ts.run()
        if result ~= nil then
          local to_update_object = {}
          for s in result:gmatch("[^\r\n]+") do
            table.insert(to_update_object, s)
          end
          query.update_one(M.selected_collection, to_update_object)
          vim.api.nvim_set_current_win(buffer.command_win)
        end
      end,
      opts = { buffer = buffer.result_buf },
    },
    {
      mode = "n",
      lhs = "d",
      rhs = function()
        local result = ts.run()
        if result ~= nil then
          local to_update_object = {}
          for s in result:gmatch("[^\r\n]+") do
            table.insert(to_update_object, s)
          end
          query.delete_one(M.selected_collection, to_update_object)
          vim.api.nvim_set_current_win(buffer.command_win)
        end
      end,
      opts = { buffer = buffer.result_buf },
    },
  }
  utils.mapkeys(op, map)
end

M.select_collection = function()
  M.selected_collection = utils.get_line()

  query.find(M.selected_collection)
  vim.api.nvim_set_current_win(buffer.command_win)
  if M.config.find_on_collection_selected then
    M.execute_query_fn(query.find, M.selected_collection)
  end

  M.set_query_keymap("set")
  M.current_state = constant.state.collection_selected
  vim.defer_fn(function() end, 0)
end

M.execute = function(queries)
  local query_string = queries
  if type(queries) == "table" then
    query_string = table.concat(queries, " ")
  end

  run_async_command(query_string, function(out)
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

      buffer.create_result_buf()
      M.set_result_keymap("set")
      vim.api.nvim_set_option_value("modifiable", true, { buf = buffer.result_buf })
      buffer.show_result(text)
      vim.api.nvim_set_current_win(buffer.result_win)
      vim.api.nvim_set_option_value("modifiable", false, { buf = buffer.result_buf })
    end, 0)
  end)
end

M.execute_asking = function(queries)
  vim.ui.input({ prompt = "Execute query?: [Y/n]" }, function(answer)
    if answer ~= "y" and answer ~= "Y" and answer ~= "" and answer ~= nil then
      return
    end

    M.execute(queries)
  end)
end

M.execute_query_fn = function(queryFunction, args)
  queryFunction(args)
  local queries = utils.get_all_lines()
  M.execute(queries)
end

---back go back to the previous state
M.back = function()
  if M.current_state == constant.state.collection_selected then
    M.set_query_keymap("del")
    M.current_state = constant.state.db_selected
    M.selected_collection = ""
    M.collections = {}
    buffer.delete_result_win()
    M.show_collections_async()
  elseif M.current_state == constant.state.db_selected then
    M.set_show_collections_keymap("del")
    M.current_state = constant.state.connected
    M.dbs_filtered = {}
    M.selected_db = ""
    M.show_dbs_async()
  elseif M.current_state == constant.state.connected then
    M.set_show_dbs_keymaps("del")
    M.current_state = constant.state.init
    M.is_legacy = false
    buffer.set_connection_win_content({ constant.host_example, "", M.url })
    M.set_connect_keymaps("set")
    clean()
  end
end

return M
