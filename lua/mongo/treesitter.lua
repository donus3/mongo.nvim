Treesitter = {}

---run treesitter query to get entire document under the current cursor
---@return string[] 1 lines of document
---@return string 2 identifier
Treesitter.getDocument = function()
  local ts = vim.treesitter
  local ts_util = require("nvim-treesitter.ts_utils")
  local parsers = require("nvim-treesitter.parsers")
  local document_lines = {}

  local query_object_in_array_string = [[
    [
      ; Case 1: Object inside an array
      (expression_statement
        (array
          (object) @root_object
        )
      )

      ; Case 2: Object
      (expression_statement
        (object) @root_object
      )
    ]
  ]]

  local parser = parsers.get_parser()
  local tree = parser:parse()[1]
  local root = tree:root()
  local lang = parser:lang()
  local query = ts.query.parse(lang, query_object_in_array_string)
  local root_object_string = ""
  local identifier = ""

  for _, match in query:iter_matches(root, 0) do
    for _, node in pairs(match) do
      if ts.is_ancestor(node, ts_util.get_node_at_cursor()) then
        root_object_string = ts.get_node_text(node, 0)
        identifier = ts.get_node_text(node:child(1), 0)
      end
    end
  end

  local root_object_lines = {}
  for s in root_object_string:gmatch("[^\r\n]+") do
    table.insert(root_object_lines, s)
  end

  if #root_object_lines > 0 then
    return root_object_lines, identifier
  end

  return { root_object_string }, identifier
end

---run treesitter query to get target query under the current cursor
---@return string | nil
Treesitter.getQueryInScope = function()
  local ts = vim.treesitter
  local parsers = require("nvim-treesitter.parsers")
  local ts_util = require("nvim-treesitter.ts_utils")

  local query_string = [[
  ((identifier) @scope
    (#any-of? @scope "begin" "end")
    (#has-ancestor? @scope program)) @scope_program
]]

  local parser = parsers.get_parser()
  local tree = parser:parse()[1]
  local root = tree:root()
  local lang = parser:lang()
  local query = ts.query.parse(lang, query_string)

  local node_at_cursor = ts.get_node()
  local cursor_start_line = node_at_cursor:range()

  local result_start_line = -1
  local result_end_line = 1000000

  for _, match, _ in query:iter_matches(root, 0, 0, -1, { all = true }) do
    for id, nodes in pairs(match) do
      local node = nodes[1]
      local name = query.captures[id]
      local node_name = ts.get_node_text(node, 0)
      if name == "scope_program" then
        local scope_start_line = node:range()
        if node_name == "begin" then
          local new_distance = cursor_start_line - scope_start_line
          local current_distance = cursor_start_line - result_start_line
          if new_distance >= 0 and new_distance <= current_distance then
            result_start_line = scope_start_line
          end
        elseif node_name == "end" then
          local new_distance = scope_start_line - cursor_start_line
          local current_distance = result_end_line - cursor_start_line
          if new_distance >= 0 and new_distance <= current_distance then
            result_end_line = scope_start_line
          end
        end
      end
    end
  end

  local lines = vim.api.nvim_buf_get_lines(0, result_start_line + 1, result_end_line, false)
  return lines
end

return Treesitter
