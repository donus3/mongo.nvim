---@class Node
Node = {
  ---@type Node[] | nil
  children = nil,
  ---@type boolean
  is_expanded = false,
  ---@type Database | Collection | table | nil
  value = nil,
  ---@type function | nil
  handler = nil,
}

Node.__index = Node

---@param value Database | Collection | table
---@param isExpanded boolean
---@param handler function | nil
function Node:new(value, isExpanded, handler)
  local instance = setmetatable({}, Node)
  instance.value = value
  instance.is_expanded = isExpanded or false
  instance:register_handler(handler)
  return instance
end

function Node:register_handler(handler)
  if handler ~= nil then
    self.handler = function()
      handler(self)
      self.is_expanded = not self.is_expanded
    end
  else
    self.handler = function()
      -- Assuming 'vim' might not always be available, guard its usage or use a generic print
      if vim and vim.notify and vim.log and vim.log.levels then
        vim.notify("Missing handler for " .. (self.value and self.value.name or "unknown node"), vim.log.levels.ERROR)
      else
        print("Error: Missing handler for " .. (self.value and self.value.name or "unknown node"))
      end
      self.is_expanded = not self.is_expanded
    end
  end
end

---@param child Node
function Node:add_child(child)
  if self.children == nil then
    self.children = {}
  end
  table.insert(self.children, child)
end

---@class Tree
Tree = {
  ---@type Node | nil
  root = nil,
}

Tree.__index = Tree

function Tree:new()
  local instance = setmetatable({}, Tree)
  return instance
end

---@param node Node
function Tree:set_root(node)
  self.root = node
end

---@param name string
---@param type string
---@param node Node | nil
---@return {target: Node| nil, root: Node|nil} -- Note: 'root' in return seems to mean 'parent of target'
function Tree:find_node(name, type, node)
  local current_node = node or self.root
  if current_node == nil then
    return { target = nil, root = nil }
  end

  if current_node.value and current_node.value.name == name and current_node.value.__type == type then
    return { target = current_node, root = nil } -- If target is current_node, its direct parent is not returned here.
    -- The 'root' in the return seems to mean parent in recursive calls.
  end

  if current_node.children == nil then
    return { target = nil, root = nil }
  end

  for _, child in ipairs(current_node.children) do
    -- If the direct child is the target
    if child.value and child.value.name == name and child.value.__type == type then
      return { target = child, root = current_node } -- Return child as target, current_node as its parent (root for this find)
    end
    -- Recurse
    local result = self:find_node(name, type, child) -- Pass child as the node to inspect
    if result.target ~= nil then
      -- If target found deeper, propagate the result.
      -- The `result.root` would be the parent of `result.target` from deeper recursion.
      return result
    end
  end

  return { target = nil, root = nil }
end

---@param node Node | nil
---@param depth integer
---@param result { display: string, handler: function, is_expanded: boolean, is_parent_expanded: boolean, node_type: string }[]
---@param is_parent_expanded boolean | nil
---@return { display: string, handler: function, is_expanded: boolean, is_parent_expanded: boolean, node_type: string }[]
function Tree:draw(node, depth, result, is_parent_expanded)
  local current_node = node or self.root
  if current_node == nil then
    return result
  end

  local depth_space = ""
  for _ = 2, depth do
    depth_space = depth_space .. "  " -- Using two spaces for indentation consistency
  end

  -- Skip drawing the system root node itself (depth 0)
  if depth ~= 0 then
    table.insert(result, {
      display = depth_space .. (current_node.value and current_node.value.name or "Unnamed Node"),
      handler = current_node.handler,
      is_expanded = current_node.is_expanded,
      is_parent_expanded = is_parent_expanded,               -- True if the direct parent is expanded
      node_type = depth == 1 and "Database" or "Collection", -- Type based on display depth
    })
  end

  if current_node.children == nil then
    return result
  end

  for _, child in ipairs(current_node.children) do
    result = self:draw(child, depth + 1, result, current_node.is_expanded)
  end

  return result
end

--- Builds a tree from a flat list of strings.
--- Strings without leading spaces become first-level nodes (e.g., "Database").
--- Strings with leading spaces become second-level nodes (e.g., "Collection")
--- under the last processed first-level node.
--- Max display depth of nodes created this way will be two.
---@param strings string[] A table of strings.
---@param database_node_handler function | nil An optional handler function for each database created node.
---@param collection_node_handler function | nil An optional handler function for each collection created node.
---@return Tree The newly constructed tree.
local function build_tree_from_strings(strings, database_node_handler, collection_node_handler)
  local tree = Tree:new()
  -- This system root node acts as a container and won't be displayed by `Tree:draw` if depth 0 is skipped.
  -- It's marked as expanded so its children (the actual first-level items) are processed.
  local system_root_node = Node:new({ name = "__SYSTEM_ROOT__", __type = "SystemRoot" }, true, nil)
  tree:set_root(system_root_node)

  local current_depth1_node = nil -- Tracks the last created first-depth node

  for _, original_str_value in ipairs(strings) do
    -- Trim all surrounding whitespace for the node's name
    local node_name = original_str_value:match("^%s*(.-)%s*$")

    -- Process only if the string has actual content after trimming
    if node_name and node_name ~= "" then
      -- Check the *original* string for a leading space to determine hierarchy
      local has_leading_space = string.match(original_str_value, "^%s") ~= nil

      if not has_leading_space then
        -- This is a first-depth node (will be typed as "Database" by Tree:draw)
        local db_node = Database:new(node_name)
        local new_node = Node:new(db_node, false, database_node_handler(db_node))
        system_root_node:add_child(new_node)
        current_depth1_node = new_node -- This node is now the parent for subsequent indented items
      else
        -- This is a second-depth node (will be typed as "Collection" by Tree:draw)
        if current_depth1_node then
          local collection_node = Collection:new(node_name)
          local new_node =
              Node:new(collection_node, false, collection_node_handler(current_depth1_node, collection_node))
          current_depth1_node:add_child(new_node)
        else
          -- This indented string has no preceding non-indented parent. Skip it.
          local message = "Warning: Orphaned item: '" .. node_name .. "' (indented, but no parent). Skipping."
          if vim and vim.notify and vim.log and vim.log.levels then
            vim.notify(message, vim.log.levels.WARN)
          else
            print(message)
          end
        end
      end
    end
  end

  return tree
end

-- To make this a module:
return {
  Node = Node,
  Tree = Tree,
  build_tree_from_strings = build_tree_from_strings,
}
