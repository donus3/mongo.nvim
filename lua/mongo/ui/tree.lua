---@class Node
Node = {
  ---@type Node[] | nil
  children = nil,
  ---@type boolean
  isExpanded = false,
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
  instance.isExpanded = isExpanded or false
  instance:register_handler(handler)
  return instance
end

function Node:register_handler(handler)
  if handler ~= nil then
    self.handler = function()
      handler(self)
      self.isExpanded = not self.isExpanded
    end
  else
    self.handler = function()
      vim.notify("missing handler for " .. self.value.name, vim.log.levels.ERROR)
      self.isExpanded = not self.isExpanded
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
---@return {target: Node| nil, root: Node|nil}
function Tree:find_node(name, type, node)
  local current_node = node or self.root
  if current_node == nil then
    return { target = nil, root = nil }
  end

  if current_node.value.name == name and current_node.value.__type == type then
    return { target = current_node, root = nil }
  end

  if current_node.children == nil then
    return { target = nil, root = nil }
  end

  for _, child in ipairs(current_node.children) do
    local result = self:find_node(name, type, child)
    if result.target ~= nil then
      return { target = result.target, root = child }
    end
  end

  return { target = nil, root = nil }
end

---@param node Node | nil
function Tree:draw(node, depth, result)
  local current_node = node or self.root
  if current_node == nil then
    return result
  end

  local depth_space = ""
  for i = 2, depth do
    depth_space = depth_space .. "  "
  end

  -- skip root
  if depth ~= 0 then
    table.insert(result, {
      display = depth_space .. current_node.value.name,
      handler = current_node.handler,
    })
  end

  if current_node.children == nil then
    return result
  end

  for _, child in ipairs(current_node.children) do
    result = self:draw(child, depth + 1, result)
  end

  return result
end

return {
  Tree = Tree,
  Node = Node,
}
