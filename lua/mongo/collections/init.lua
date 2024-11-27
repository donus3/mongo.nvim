---@class Collection
Collection = {
  ---@type string
  name = "",
  ---@type string[]
  fields = {},
}

Collection.__index = Collection
Collection.__type = "Collection"

---@param name string the collection's name
---@return Collection
function Collection:new(name)
  local instance = setmetatable({}, Collection)
  instance.name = name

  return instance
end

---@param fields string[] the collection's fields
function Collection:set_fields(fields)
  self.fields = fields
end

return Collection
