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

---create a new connection working space scratch buffer if not exist
---@param session Session
Buffer.create_connection_buf = function(session)
  if not session.connection_buf then
    vim.cmd("tabnew")

    ss.set_session_field(session.name, "tabpage_num", vim.api.nvim_tabpage_get_number(0))
    ss.set_session_field(session.name, "connection_win", vim.api.nvim_tabpage_get_win(0))
    local tab_buf = vim.api.nvim_get_current_buf()
    ss.set_session_field(session.name, "connection_buf", vim.api.nvim_create_buf(false, true))
    vim.api.nvim_buf_set_name(session.connection_buf, constant.connection_buf_name .. session.name)
    vim.api.nvim_win_set_buf(session.connection_win, session.connection_buf)
    vim.bo[session.connection_buf].filetype = "mongo-connection"
    force_delete_buffer(tab_buf)

    -- clean up autocmd when leave
    local group = vim.api.nvim_create_augroup("MongoDBConnectionLeave", { clear = true })
    vim.api.nvim_create_autocmd("WinClosed", {
      group = group,
      buffer = session.connection_buf,
      callback = function()
        if session.connection_win ~= nil then
          force_delete_buffer(session.connection_buf)
        end
        ss.set_session_field(session.name, "connection_buf", nil)
        ss.set_session_field(session.name, "connection_win", nil)
      end,
    })
  end
end

---set contents in the connection working space
---@param session Session
---@param contents string[] each item in the table is one line
Buffer.set_connection_win_content = function(session, contents)
  if session.connection_buf == nil then
    Buffer.create_connection_buf(session)
  end

  vim.api.nvim_buf_set_lines(session.connection_buf, 0, -1, true, contents)
end

---create a new command working space scratch buffer if not exist
---@param session Session
Buffer.create_command_buf = function(session)
  if not session.command_buf then
    vim.cmd("vsplit")
    ss.set_session_field(session.name, "command_win", vim.api.nvim_get_current_win())

    -- resize the connection window
    if session.connection_win ~= nil then
      local current_connection_win_width = vim.api.nvim_win_get_width(session.connection_win)
      local connection_win_width = math.floor(current_connection_win_width * 0.5)
      if connection_win_width < 20 then
        connection_win_width = 20
      end

      vim.api.nvim_win_set_width(session.connection_win, connection_win_width)
    end

    ss.set_session_field(session.name, "command_buf", vim.api.nvim_create_buf(false, true))
    vim.api.nvim_buf_set_name(session.command_buf, constant.command_buf_name .. session.name)
    vim.api.nvim_win_set_buf(session.command_win, session.command_buf)
    vim.bo[session.command_buf].filetype = "javascript"

    -- clean up autocmd when leave
    local group = vim.api.nvim_create_augroup("MongoDBCommandLeave", { clear = true })
    vim.api.nvim_create_autocmd("WinClosed", {
      group = group,
      buffer = session.command_buf,
      callback = function()
        if session.command_win ~= nil then
          force_delete_buffer(session.command_buf)
        end
        ss.set_session_field(session.name, "command_buf", nil)
        ss.set_session_field(session.name, "command_win", nil)
      end,
    })
  end
end

---set contents in the command working space
---@param session Session
---@param contents string[] each item in the table is one line
Buffer.set_command_content = function(session, contents)
  if session.command_buf == nil then
    Buffer.create_command_buf(session)
  end

  vim.api.nvim_buf_set_lines(session.command_buf, 0, -1, true, contents)
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

---create a new result window and scratch buffer if not exist
---@param session Session
Buffer.create_result_buf = function(session)
  if not session.result_buf then
    vim.cmd("vsplit")
    ss.set_session_field(session.name, "result_win", vim.api.nvim_get_current_win())
    ss.set_session_field(session.name, "result_buf", vim.api.nvim_create_buf(false, true))
    vim.api.nvim_buf_set_name(session.result_buf, constant.result_buf_name .. session.name)
    vim.api.nvim_win_set_buf(session.result_win, session.result_buf)
    vim.bo[session.result_buf].filetype = "javascript"
    if session.command_win ~= nil then
      vim.api.nvim_set_current_win(session.command_win)
    end

    -- clean up autocmd when leave
    local group = vim.api.nvim_create_augroup("MongoDBResultLeave", { clear = true })
    vim.api.nvim_create_autocmd("WinClosed", {
      group = group,
      buffer = session.result_buf,
      callback = function()
        if session.result_win ~= nil then
          force_delete_buffer(session.result_buf)
        end
        ss.set_session_field(session.name, "result_buf", nil)
        ss.set_session_field(session.name, "result_win", nil)
      end,
    })
  end
end

---delete result buffer and close window
---@param session Session
Buffer.delete_result_win = function(session)
  if session.result_win ~= nil then
    vim.api.nvim_win_close(session.result_win, true)
    ss.set_session_field(session.name, "result_win", nil)
  end

  if session.result_buf ~= nil then
    force_delete_buffer(session.result_buf)
    ss.set_session_field(session.name, "result_buf", nil)
  end
end

---clean up all buffers and close all windows
---@param session Session
Buffer.clean = function(session)
  local toClean = {
    "result",
    "command",
    "connection",
  }

  for _, v in ipairs(toClean) do
    local bufName = v .. "_buf"
    local winName = v .. "_win"
    if session[bufName] ~= nil then
      ss.set_session_field(session.name, bufName, nil)
      if session[winName] ~= nil then
        ss.set_session_field(session.name, winName, nil)
      end
    end
  end

  vim.cmd("tabclose")
end

return Buffer
