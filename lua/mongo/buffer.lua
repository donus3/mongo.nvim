---@class Buffer
local M = {}
M.command_buf = nil
M.command_win = nil
M.result_buf = nil
M.result_win = nil
M.connection_buf = nil
M.connection_win = nil

local command_buf_name = "MongoDB Working Space"
local result_buf_name = "MongoDB Query Results"
local connection_buf_name = "MongoDB Connection"

---delete buffer and close window
---@param buf number
local force_delete_buffer = function(buf)
  if vim.api.nvim_buf_is_loaded(buf) then
    vim.cmd("bd! " .. buf)
  end
end

---find buffer by name. Return -1 if not exist
---@param name string
---@return number
local find_buffer_by_name = function(name)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local buf_name = vim.api.nvim_buf_get_name(buf)
    if buf_name == vim.fn.expand("%:p:h") .. "/" .. name then
      return buf
    end
  end
  return -1
end

---create a new connection working space scratch buffer if not exist
M.create_connection_buf = function()
  if not M.connection_buf then
    vim.cmd("tabnew")
    M.connection_win = vim.api.nvim_tabpage_get_win(0)
    local tab_buf = vim.api.nvim_get_current_buf()

    local existing_buf = find_buffer_by_name(connection_buf_name)
    if existing_buf ~= -1 then
      force_delete_buffer(existing_buf)
    end
    M.connection_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(M.connection_buf, connection_buf_name)
    vim.api.nvim_win_set_buf(M.connection_win, M.connection_buf)
    force_delete_buffer(tab_buf)

    -- clean up autocmd when leave
    local group = vim.api.nvim_create_augroup("MongoDBConnectionLeave", { clear = true })
    vim.api.nvim_create_autocmd("WinClosed", {
      group = group,
      buffer = M.connection_buf,
      callback = function()
        if M.connection_win ~= nil then
          force_delete_buffer(M.connection_buf)
        end
        M.connection_buf = nil
        M.connection_win = nil
      end,
    })
  end
end

---set contents in the connection working space
---@param contents string[] each item in the table is one line
M.set_connection_win_content = function(contents)
  if M.connection_buf == nil then
    M.create_connection_buf()
  end

  vim.api.nvim_buf_set_lines(M.connection_buf, 0, -1, true, contents)
end

---create a new command working space scratch buffer if not exist
M.create_command_buf = function()
  if not M.command_buf then
    vim.cmd("vsplit")
    M.command_win = vim.api.nvim_get_current_win()

    -- resize the connection window
    if M.connection_win ~= nil then
      local current_connection_win_width = vim.api.nvim_win_get_width(M.connection_win)
      local connection_win_width = math.floor(current_connection_win_width * 0.5)
      if connection_win_width < 20 then
        connection_win_width = 20
      end

      print("connection win width: " .. connection_win_width)
      vim.api.nvim_win_set_width(M.connection_win, connection_win_width)
    end

    -- attach buffer to the command window
    local existing_buf = find_buffer_by_name(command_buf_name)
    if existing_buf ~= -1 then
      M.command_buf = existing_buf
      force_delete_buffer(existing_buf)
    end
    M.command_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(M.command_buf, command_buf_name)
    vim.api.nvim_win_set_buf(M.command_win, M.command_buf)
    vim.bo[M.command_buf].filetype = "javascript"

    -- clean up autocmd when leave
    local group = vim.api.nvim_create_augroup("MongoDBCommandLeave", { clear = true })
    vim.api.nvim_create_autocmd("WinClosed", {
      group = group,
      buffer = M.command_buf,
      callback = function()
        if M.command_win ~= nil then
          force_delete_buffer(M.command_buf)
        end
        M.command_buf = nil
        M.command_win = nil
      end,
    })
  end
end

---set contents in the command working space
---@param contents string[] each item in the table is one line
M.set_command_content = function(contents)
  if M.command_buf == nil then
    M.create_command_buf()
  end

  vim.api.nvim_buf_set_lines(M.command_buf, 0, -1, true, contents)
end

---show contents in the query result space
---@param contents string[] each item in the table is one line
M.show_result = function(contents)
  if not M.result_buf then
    M.create_result_buf()
  end

  vim.api.nvim_buf_set_lines(M.result_buf, 0, -1, true, contents)
end

---create a new result window and scratch buffer if not exist
M.create_result_buf = function()
  if not M.result_buf then
    vim.cmd("vsplit")

    M.result_win = vim.api.nvim_get_current_win()

    local existing_buf = find_buffer_by_name(result_buf_name)
    if existing_buf ~= -1 then
      M.result_buf = existing_buf
      force_delete_buffer(existing_buf)
    end
    M.result_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(M.result_buf, result_buf_name)
    vim.api.nvim_win_set_buf(M.result_win, M.result_buf)
    vim.bo[M.result_buf].filetype = "javascript"
    if M.command_win ~= nil then
      vim.api.nvim_set_current_win(M.command_win)
    end

    -- clean up autocmd when leave
    local group = vim.api.nvim_create_augroup("MongoDBResultLeave", { clear = true })
    vim.api.nvim_create_autocmd("WinClosed", {
      group = group,
      buffer = M.result_buf,
      callback = function()
        if M.result_win ~= nil then
          force_delete_buffer(M.result_buf)
        end
        M.result_buf = nil
        M.result_win = nil
      end,
    })
  end
end

---delete result buffer and close window
M.delete_result_win = function()
  if M.result_win ~= nil then
    vim.api.nvim_win_close(M.result_win, true)
    M.result_win = nil
  end

  if M.result_buf ~= nil then
    force_delete_buffer(M.result_buf)
    M.result_buf = nil
  end
end

---clean up all buffers and close all windows
M.clean = function()
  if M.command_buf ~= nil then
    force_delete_buffer(M.command_buf)
    if M.command_win ~= nil then
      vim.api.nvim_win_close(M.command_win, true)
    end
  end
  if M.result_buf ~= nil then
    force_delete_buffer(M.result_buf)
    if M.result_win ~= nil then
      vim.api.nvim_win_close(M.result_win, true)
    end
  end
  if M.connection_buf ~= nil then
    force_delete_buffer(M.connection_buf)
    if M.connection_win ~= nil then
      vim.api.nvim_win_close(M.connection_win, true)
    end
  end

  M.command_buf = nil
  M.command_win = nil
  M.result_buf = nil
  M.result_win = nil
  M.connection_buf = nil
  M.connection_win = nil
end

return M
