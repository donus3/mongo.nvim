M = {}

---run treesitter query to get entire document under the current cursor
---@return string | nil
M.run = function()
  local ts = vim.treesitter
  local parsers = require("nvim-treesitter.parsers")
  local ts_util = require("nvim-treesitter.ts_utils")

  local query_string = [[
  (expression_statement
    (array
      (object) @root_object
    )
  )
]]

  local parser = parsers.get_parser()
  local tree = parser:parse()[1]
  local root = tree:root()
  local lang = parser:lang()

  local query = ts.query.parse(lang, query_string)

  for _, match, _ in query:iter_matches(root, 0) do
    for _, node in pairs(match) do
      if ts.is_ancestor(node, ts_util.get_node_at_cursor()) then
        return ts.get_node_text(node, 0)
      end
    end
  end
end

return M
