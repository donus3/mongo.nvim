local buffer = require("mongo.buffer")

---@class Query
local M = {}

---snippet insertOne query
---@param session Session
---@param collection string
M.insert_one = function(session, collection)
  local queryLines = {
    string.format("db['%s'].insertOne({", collection),
    "  ",
    "})",
  }
  buffer.set_command_content(session, { "/** Insert One */", table.unpack(queryLines) })
  vim.cmd(":3")
end

---snippet deleteOne query
---@param session Session
---@param collection string
---@param document? string[] | nil
M.delete_one = function(session, collection, document)
  local queryLines = {
    string.format("db['%s'].deleteOne({", collection),
  }
  if document ~= nil and document[2] ~= nil then
    table.insert(queryLines, document[2])
  else
    table.insert(queryLines, "  ")
  end
  table.insert(queryLines, "})")
  buffer.set_command_content(session, { "/** Delete One */", table.unpack(queryLines) })
  vim.cmd(":3")
end

---snippet updateOne query
---@param session Session
---@param collection string
---@param document? string[] | nil
M.update_one = function(session, collection, document)
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

  buffer.set_command_content(session, { "/** Update One */", table.unpack(queryLines) })
  vim.cmd(":3")
end

---snippet find query
---@param session Session
---@param collection string
M.find = function(session, collection)
  local queryLines = {
    string.format("db['%s'].find({", collection),
    "  ",
    "})",
    "  .limit(10)",
    "  .toArray()",
  }

  buffer.set_command_content(session, { table.unpack(queryLines) })
  vim.cmd(":3")
end

return M
