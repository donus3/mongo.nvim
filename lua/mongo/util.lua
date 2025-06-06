local Util = {}

---get text of all lines
---@return string[]
Util.get_all_lines = function()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

---get text of current line
---@return string
Util.get_line = function()
  return vim.api.nvim_get_current_line()
end

---
---@class MapConfig
---@inlinedoc
---@field mode string|string[] Mode short-name, see |nvim_set_keymap()|.
---                            Can also be list of modes to create mapping on multiple modes.
---@field lhs string           Left-hand side |{lhs}| of the mapping.
---@field rhs? string|function  Right-hand side |{rhs}| of the mapping, can be a Lua function.
---@field opts? vim.keymap.set.Opts
---
---mapkeys sets or dels keymaps based on the given op and configs
---@param op "set" | "del"
---@param configs MapConfig[]
---@return nil
Util.mapkeys = function(op, configs)
  for _, config in ipairs(configs) do
    if op == "set" then
      vim.keymap.set(config.mode, config.lhs, config.rhs, config.opts)
    else
      vim.keymap.set(config.mode, config.lhs, "", config.opts)
    end
  end
end

Util.find_in_array = function(tbl, value)
  for i, v in ipairs(tbl) do
    if v.display == value then
      return tbl[i]
    end
  end
  return nil
end

--- Converts a string into a table of strings, splitting by the newline character '\n'.
-- Each line becomes an element in the table.
--
-- @param input_str The string to be split. If nil, an empty table is returned.
-- @return A table of strings, where each element is a line from the input string.
Util.string_to_table_lines = function(input_str)
  if input_str == nil then
    return {}
  end

  local lines = {}
  for line in string.gmatch(input_str, "([^\n]*)") do
    table.insert(lines, line)
  end

  return lines
end
return Util
