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
Treesitter.getQuery = function()
  local ts = vim.treesitter
  local parsers = require("nvim-treesitter.parsers")
  local ts_util = require("nvim-treesitter.ts_utils")

  local query_string = [[
    (program
      (expression_statement) @root_expression
      (empty_statement)
    )
]]

  local parser = parsers.get_parser()
  local tree = parser:parse()[1]
  local root = tree:root()
  local lang = parser:lang()

  for _, match, _ in ts.query.parse(lang, query_string):iter_matches(root, 0) do
    for _, node in pairs(match) do
      if ts.is_ancestor(node, ts_util.get_node_at_cursor()) then
        return ts.get_node_text(node, 0)
      end
    end
  end

  local query_string_2 = [[
    (program
      (empty_statement)
      (expression_statement) @root_expression
    )
]]

  for _, match, _ in ts.query.parse(lang, query_string_2):iter_matches(root, 0) do
    for _, node in pairs(match) do
      if ts.is_ancestor(node, ts_util.get_node_at_cursor()) then
        return ts.get_node_text(node, 0)
      end
    end
  end
end

return Treesitter
