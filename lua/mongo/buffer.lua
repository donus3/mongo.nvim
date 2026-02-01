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

---@param workspace Workspace
---@param key 'connection' | 'database' | 'query' | 'result'
---@param group_name string
local close_buf_hook = function(workspace)
  local group = vim.api.nvim_create_augroup("MongoLeave", { clear = true })

  for k, v in pairs(workspace.space) do
    vim.defer_fn(function()
      vim.keymap.set("n", "gq", ":q<cr>", { buffer = v.buf })

      --- clean up autocmd
      vim.api.nvim_create_autocmd("WinClosed", {
        group = group,
        buffer = v.buf,
        callback = function()
          for k2, v2 in pairs(workspace.space) do
            if v2.win ~= nil then
              force_delete_buffer(v2.buf)
            end
            workspace:reset(k2)
          end
        end,
      })
    end, 0)
  end
end

---create a new connection working space scratch buffer if not exist
---@param workspace Workspace
Buffer.create_connection_buf = function(workspace)
  if not workspace.space.connection.buf then
    vim.cmd("tabnew")

    workspace.tab_number = vim.api.nvim_tabpage_get_number(0)
    workspace.space.connection.win = vim.api.nvim_tabpage_get_win(0)

    local tab_buf = vim.api.nvim_get_current_buf()
    workspace.space.connection.buf = vim.api.nvim_create_buf(false, true)

    disableJump(workspace.space.connection.buf)

    vim.api.nvim_buf_set_name(
      workspace.space.connection.buf,
      constant.workspace .. workspace.name .. constant.connection_buf_name
    )
    vim.api.nvim_win_set_buf(workspace.space.connection.win, workspace.space.connection.buf)
    vim.bo[workspace.space.connection.buf].filetype = "mongo-connection"
    force_delete_buffer(tab_buf)
  end
end

---create a new .keymap.settabase working space scratch buffer if not exist
---@param workspace Workspace
Buffer.create_database_buf = function(workspace)
  if not workspace.space.database.buf then
    vim.cmd("split")
    workspace.space.database.win = vim.api.nvim_get_current_win()
    workspace.space.database.buf = vim.api.nvim_create_buf(false, true)
    local connection_win_height = vim.api.nvim_win_get_height(workspace.space.connection.win)
    local database_win_height = vim.api.nvim_win_get_height(workspace.space.database.win)
    vim.api.nvim_win_set_height(
      workspace.space.database.win,
      math.floor(0.85 * (connection_win_height + database_win_height))
    )

    disableJump(workspace.space.database.buf)

    vim.api.nvim_buf_set_name(
      workspace.space.database.buf,
      constant.workspace .. workspace.name .. constant.database_buf_name
    )
    vim.api.nvim_win_set_buf(workspace.space.database.win, workspace.space.database.buf)
    vim.bo[workspace.space.database.buf].filetype = "txt"
  end
end

---create a new .keymap.setmmand working space scratch buffer if not exist
---@param workspace Workspace
Buffer.create_query_buf = function(workspace)
  if not workspace.space.query.buf then
    local current_connection_win_width = vim.api.nvim_win_get_width(workspace.space.connection.win)
    vim.cmd("vsplit")
    workspace.space.query.win = vim.api.nvim_get_current_win()

    -- resize the connection window
    if workspace.space.connection.win ~= nil then
      local connection_win_width = math.floor(current_connection_win_width * 0.8)
      if connection_win_width < 15 then
        connection_win_width = 15
      end

      vim.api.nvim_win_set_width(workspace.space.query.win, connection_win_width)
    end

    workspace.space.query.buf = vim.api.nvim_create_buf(false, true)
    disableJump(workspace.space.query.buf)

    -- TODO: this is a hack to make the LSP work but not working yet ( . .)
    -- Get the node directory path to use as a basis for the buffer name
    -- This helps the LSP identify the correct root directory (node/)
    local script_path = debug.getinfo(1).source:match("@(.*)$")
    local node_dir = script_path:gsub("lua/mongo/buffer.lua", "node")
    local query_file_path = node_dir .. "/query.ts"

    vim.api.nvim_buf_set_name(workspace.space.query.buf, query_file_path)
    vim.api.nvim_win_set_buf(workspace.space.query.win, workspace.space.query.buf)
    vim.bo[workspace.space.query.buf].filetype = "typescript"
  end
end

---create a new .keymap.setsult window and scratch buffer if not exist
---@param workspace Workspace
Buffer.create_result_buf = function(workspace)
  if not workspace.space.result.buf then
    vim.cmd("vsplit")
    workspace.space.result.win = vim.api.nvim_get_current_win()
    workspace.space.result.buf = vim.api.nvim_create_buf(false, true)

    disableJump(workspace.space.result.buf)

    vim.api.nvim_buf_set_name(
      workspace.space.result.buf,
      constant.workspace .. workspace.name .. constant.result_buf_name
    )
    vim.api.nvim_win_set_buf(workspace.space.result.win, workspace.space.result.buf)
    vim.bo[workspace.space.result.buf].filetype = "javascript"
  end
end

---set contents .keymap.set the connection working space
---@param workspace Workspace
---@param contents string[] each item in the table is one line
Buffer.set_connection_content = function(workspace, contents)
  if workspace.space.connection.buf == nil then
    Buffer.create_connection_buf(workspace)
  end

  vim.api.nvim_buf_set_lines(workspace.space.connection.buf, 0, -1, true, contents)
end

---set contents in the database working space
---@param workspace Workspace
---@param contents string[] each item in the table is one line
Buffer.set_database_content = function(workspace, contents)
  if workspace.space.database.buf == nil then
    Buffer.create_connection_buf(workspace)
  end

  vim.api.nvim_buf_set_lines(workspace.space.database.buf, 0, -1, true, contents)
end

---set contents in the query working space
---@param workspace Workspace
---@param contents string[] each item in the table is one line
---@param isAppend boolean?
Buffer.set_query_content = function(workspace, contents, isAppend)
  if workspace.space.query.buf == nil then
    Buffer.create_query_buf(workspace)
  end

  if isAppend == nil or isAppend == false then
    vim.api.nvim_buf_set_lines(workspace.space.query.buf, 0, -1, true, contents)
  else
    vim.api.nvim_buf_set_lines(workspace.space.query.buf, -1, -1, true, contents)
  end
end

---show contents in the query result space
---@param workspace Workspace
---@param contents string[] each item in the table is one line
Buffer.show_result = function(workspace, contents)
  if not workspace.space.result.buf then
    Buffer.create_result_buf(workspace)
  end

  vim.api.nvim_buf_set_lines(workspace.space.result.buf, 0, -1, true, contents)
end

---@param workspace Workspace
Buffer.init = function(workspace)
  Buffer.create_connection_buf(workspace)
  Buffer.create_database_buf(workspace)
  Buffer.create_query_buf(workspace)
  Buffer.create_result_buf(workspace)

  vim.api.nvim_set_current_win(workspace.space.connection.win)
  -- clean up autocmd when leave
  close_buf_hook(workspace)
end

return Buffer
