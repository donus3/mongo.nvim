local Tree = require("mongo.ui.tree").Tree
local Node = require("mongo.ui.tree").Node
local Connection = require("mongo.connections")

---@class Space
Space = {
  ---@type number | nil
  buf = nil,
  ---@type number | nil
  win = nil,
}

Space.__index = Space

function Space:new(buf, win)
  local instance = setmetatable({}, Space)
  instance.buf = buf
  instance.win = win
  return instance
end

---@class Workspace
Workspace = {
  ---@type string
  name = "",

  ---@type number | nil
  tab_number = nil,

  space = {
    ---@type Space
    connection = Space:new(nil, nil),
    ---@type Space
    database = Space:new(nil, nil),
    ---@type Space
    query = Space:new(nil, nil),
    ---@type Space
    result = Space:new(nil, nil),
  },

  ---@type Config | nil
  config = nil,

  ---@type Connection
  connection = {},

  ---@type Tree | nil
  tree = nil,
}

Workspace.__index = Workspace

---@return Workspace
---@param name string the workspace name
---@param config Config
function Workspace:new(name, config)
  local instance = setmetatable({}, Workspace)

  local now = os.clock()
  local tree = Tree:new()
  local connection = Connection:new(name or now, config.default_url)

  tree:set_root(Node:new(connection, true, nil))

  instance.name = name or now
  instance.tree = tree
  instance.connection = connection
  instance.config = config

  return instance
end

---@param key string
function Workspace:reset(key)
  self.space[key].buf = nil
  self.space[key].win = nil
end

function Workspace:draw_tree()
  local draw_result = self.tree:draw(nil, 0, {})
  local lines = {}
  for _, v in ipairs(draw_result) do
    if v.node_type ~= "Collection" or (v.node_type == "Collection" and v.is_parent_expanded) then
      table.insert(lines, v.display)
    end
  end

  return lines
end

return Workspace
