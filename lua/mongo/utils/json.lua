M = {}

---decode JSON string to table
---@param json_str string
---@return table<string, any>
local decode = function(json_str)
  local normalized_json_str = json_str:gsub("'", '"')
  return vim.json.decode(normalized_json_str)
end

M.decode = decode
return M
