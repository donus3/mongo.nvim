local buffer = require("mongo.buffer")

---@class Query
local M = {}

---snippet insertOne query
---@param collection string
M.insert_one = function(collection)
  local queryLines = {
    string.format("db['%s'].insertOne({", collection),
    "  ",
    "})",
  }
  buffer.set_command_content({ "/** Insert One */", table.unpack(queryLines) })
  vim.cmd(":3")
end

---snippet deleteOne query
---@param collection string
---@param document? string[] | nil
M.delete_one = function(collection, document)
  local queryLines = {
    string.format("db['%s'].deleteOne({", collection),
  }
  if document ~= nil and document[2] ~= nil then
    table.insert(queryLines, document[2])
  else
    table.insert(queryLines, "  ")
  end
  table.insert(queryLines, "})")
  buffer.set_command_content({ "/** Delete One */", table.unpack(queryLines) })
  vim.cmd(":3")
end

---snippet updateOne query
---@param collection string
---@param document? string[] | nil
M.update_one = function(collection, document)
  local queryLines = {
    string.format("db['%s'].updateOne({", collection),
  }

  if document ~= nil and document[2] ~= nil then
    table.insert(queryLines, document[2])
  else
    table.insert(queryLines, "  ")
  end

  table.insert(queryLines, "}, {")
  table.insert(queryLines, "  $set: ")

  for _, line in ipairs(document or { "  {}" }) do
    table.insert(queryLines, line)
  end

  table.insert(queryLines, "})")

  buffer.set_command_content({ "/** Update One */", table.unpack(queryLines) })
  vim.cmd(":3")
end

---snippet find query
---@param collection string
M.find = function(collection)
  local queryLines = {
    string.format("db['%s'].find({", collection),
    "  ",
    "})",
    "  .limit(10)",
    "  .toArray()",
  }

  buffer.set_command_content({ table.unpack(queryLines) })
  vim.cmd(":3")
end

return M
