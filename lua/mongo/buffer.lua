local ss = require("mongo.session")
local constant = require("mongo.constant")

---@class Buffer
local Buffer = {}

---delete buffer and close window
---@param buf number
local force_delete_buffer = function(buf)
  if vim.api.nvim_buf_is_loaded(buf) then
    vim.cmd("bd! " .. buf)
  end
end

local disableJump = function(buf)
  vim.defer_fn(function()
    vim.api.nvim_buf_set_keymap(buf, "n", "<c-o>", "", {})
  end, 0)
end

local close_buf_hook = function(session, buf_name, group_name)
  local group = vim.api.nvim_create_augroup(group_name, { clear = true })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    buffer = session[buf_name .. "_buf"],
    callback = function()
      if session[buf_name .. "_win"] ~= nil then
        force_delete_buffer(session[buf_name .. "_buf"])
      end
      ss.set_session_field(session.name, buf_name .. "_buf", nil)
      ss.set_session_field(session.name, buf_name .. "_win", nil)
    end,
  })
end

---create a new connection working space scratch buffer if not exist
---@param session Session
Buffer.create_connection_buf = function(session)
  if not session.connection_buf then
    vim.cmd("tabnew")

    ss.set_session_field(session.name, "tabpage_num", vim.api.nvim_tabpage_get_number(0))
    ss.set_session_field(session.name, "connection_win", vim.api.nvim_tabpage_get_win(0))
    local tab_buf = vim.api.nvim_get_current_buf()
    ss.set_session_field(session.name, "connection_buf", vim.api.nvim_create_buf(false, true))
    disableJump(session.connection_buf)
    vim.api.nvim_buf_set_name(session.connection_buf, constant.connection_buf_name .. session.name)
    vim.api.nvim_win_set_buf(session.connection_win, session.connection_buf)
    vim.bo[session.connection_buf].filetype = "mongo-connection"
    force_delete_buffer(tab_buf)

    -- clean up autocmd when leave
    close_buf_hook(session, "connection", constant.connection_buf_name)
  end
end

---create a new database working space scratch buffer if not exist
---@param session Session
Buffer.create_database_buf = function(session)
  if not session.database_buf then
    vim.cmd("split")
    ss.set_session_field(session.name, "database_win", vim.api.nvim_get_current_win())

    ss.set_session_field(session.name, "database_buf", vim.api.nvim_create_buf(false, true))
    disableJump(session.database_buf)
    vim.api.nvim_buf_set_name(session.database_buf, constant.database_buf_name .. session.name)
    vim.api.nvim_win_set_buf(session.database_win, session.database_buf)
    vim.bo[session.database_buf].filetype = "txt"

    -- clean up autocmd when leave
    close_buf_hook(session, "database", constant.database_buf_name)
  end
end

---create a new collection working space scratch buffer if not exist
---@param session Session
Buffer.create_collection_buf = function(session)
  if not session.collection_buf then
    local current_connection_win_height = vim.api.nvim_win_get_height(session.database_win)
    vim.cmd("split")
    ss.set_session_field(session.name, "collection_win", vim.api.nvim_get_current_win())

    -- resize the connection & database window
    vim.api.nvim_win_set_height(session.connection_win, 5)
    vim.api.nvim_win_set_height(session.database_win, 7)

    ss.set_session_field(session.name, "collection_buf", vim.api.nvim_create_buf(false, true))
    disableJump(session.collection_buf)
    vim.api.nvim_buf_set_name(session.collection_buf, constant.collection_buf_name .. session.name)
    vim.api.nvim_win_set_buf(session.collection_win, session.collection_buf)
    vim.bo[session.collection_buf].filetype = "txt"

    -- clean up autocmd when leave
    close_buf_hook(session, "collection", constant.collection_buf_name)
  end
end

---create a new command working space scratch buffer if not exist
---@param session Session
Buffer.create_query_buf = function(session)
  if not session.query_buf then
    local current_connection_win_width = vim.api.nvim_win_get_width(session.connection_win)
    vim.cmd("vsplit")
    ss.set_session_field(session.name, "query_win", vim.api.nvim_get_current_win())

    -- resize the connection window
    if session.connection_win ~= nil then
      local connection_win_width = math.floor(current_connection_win_width * 0.8)
      if connection_win_width < 15 then
        connection_win_width = 15
      end

      vim.api.nvim_win_set_width(session.query_win, connection_win_width)
    end

    ss.set_session_field(session.name, "query_buf", vim.api.nvim_create_buf(false, true))
    disableJump(session.query_buf)
    vim.api.nvim_buf_set_name(session.query_buf, constant.query_buf_name .. session.name)
    vim.api.nvim_win_set_buf(session.query_win, session.query_buf)
    vim.bo[session.query_buf].filetype = "javascript"

    -- clean up autocmd when leave
    close_buf_hook(session, "query", constant.query_buf_name)
  end
end

---create a new result window and scratch buffer if not exist
---@param session Session
Buffer.create_result_buf = function(session)
  if not session.result_buf then
    vim.cmd("vsplit")
    ss.set_session_field(session.name, "result_win", vim.api.nvim_get_current_win())
    ss.set_session_field(session.name, "result_buf", vim.api.nvim_create_buf(false, true))
    disableJump(session.result_buf)
    vim.api.nvim_buf_set_name(session.result_buf, constant.result_buf_name .. session.name)
    vim.api.nvim_win_set_buf(session.result_win, session.result_buf)
    vim.bo[session.result_buf].filetype = "javascript"

    -- clean up autocmd when leave
    close_buf_hook(session, "result", constant.result_buf_name)
  end
end

---set contents in the connection working space
---@param session Session
---@param contents string[] each item in the table is one line
Buffer.set_connection_content = function(session, contents)
  if session.connection_buf == nil then
    Buffer.create_connection_buf(session)
  end

  vim.api.nvim_buf_set_lines(session.connection_buf, 0, -1, true, contents)
end

---set contents in the database working space
---@param session Session
---@param contents string[] each item in the table is one line
Buffer.set_database_content = function(session, contents)
  if session.database_buf == nil then
    Buffer.create_connection_buf(session)
  end

  vim.api.nvim_buf_set_lines(session.database_buf, 0, -1, true, contents)
end

---set contents in the collection working space
---@param session Session
---@param contents string[] each item in the table is one line
Buffer.set_collection_content = function(session, contents)
  if session.query_buf == nil then
    Buffer.create_collection_buf(session)
  end

  vim.api.nvim_buf_set_lines(session.collection_buf, 0, -1, true, contents)
end

---set contents in the query working space
---@param session Session
---@param contents string[] each item in the table is one line
Buffer.set_query_content = function(session, contents)
  if session.query_buf == nil then
    Buffer.create_query_buf(session)
  end

  vim.api.nvim_buf_set_lines(session.query_buf, 0, -1, true, contents)
end

---show contents in the query result space
---@param session Session
---@param contents string[] each item in the table is one line
Buffer.show_result = function(session, contents)
  if not session.result_buf then
    Buffer.create_result_buf(session)
  end

  vim.api.nvim_buf_set_lines(session.result_buf, 0, -1, true, contents)
end

---clean up all buffers and close all windows
---@param session Session
Buffer.clean = function(session)
  local toClean = {
    "result",
    "query",
    "connection",
    "collection",
    "database",
  }

  for _, v in ipairs(toClean) do
    local bufName = v .. "_buf"
    local winName = v .. "_win"
    if session[bufName] ~= nil then
      if vim.api.nvim_buf_is_valid(session[bufName]) then
        vim.api.nvim_buf_delete(session[bufName], { force = true })
      end
      ss.set_session_field(session.name, bufName, nil)
      if session[winName] ~= nil then
        if vim.api.nvim_win_is_valid(session[winName]) then
          vim.api.nvim_win_close(session[winName], true)
        end
        ss.set_session_field(session.name, winName, nil)
      end
    end
  end

  ss.remove(session.name)
end

Buffer.init = function(session)
  Buffer.create_connection_buf(session)
  Buffer.create_database_buf(session)
  Buffer.create_query_buf(session)
  Buffer.create_result_buf(session)

  vim.api.nvim_set_current_win(session.database_win)
  Buffer.create_collection_buf(session)

  vim.api.nvim_set_current_win(session.connection_win)
end

return Buffer
