local buffer = require("mongo.buffer")

---@class Query
local Query = {}

---snippet insertOne query
---@param session Session
---@param collection string
Query.insert_one = function(session, collection)
  local queryLines = {
    string.format("db['%s'].insertOne({", collection),
    "  ",
    "})",
  }
  buffer.set_query_content(session, { "/** Insert One */", table.unpack(queryLines) })
  vim.cmd(":3")
end

---snippet deleteOne query
---@param session Session
---@param collection string
---@param identifier? string | nil
Query.delete_one = function(session, collection, identifier)
  local queryLines = {
    string.format("db['%s'].deleteOne({", collection),
  }
  if identifier ~= nil then
    table.insert(queryLines, "  " .. identifier)
  else
    table.insert(queryLines, "  ")
  end
  table.insert(queryLines, "})")
  buffer.set_query_content(session, { "/** Delete One */", table.unpack(queryLines) })
  vim.cmd(":3")
end

---snippet updateOne query
---@param session Session
---@param collection string
---@param document? table<string[], string> | nil
Query.update_one = function(session, collection, document)
  local queryLines = {
    string.format("db['%s'].updateOne({", collection),
  }

  if document ~= nil and document[2] ~= nil then
    table.insert(queryLines, "  " .. document[2])
  else
    table.insert(queryLines, "  ")
  end

  table.insert(queryLines, "}, {")

  if document ~= nil and document[1] ~= nil then
    table.insert(queryLines, "  $set: ")
    for _, line in ipairs(document[1]) do
      table.insert(queryLines, line)
    end
  else
    table.insert(queryLines, "  {}")
  end
  table.insert(queryLines, "})")

  buffer.set_query_content(session, { "/** Update One */", table.unpack(queryLines) })
  vim.cmd(":3")
end

---snippet find query
---@param session Session
---@param collection string
---@param filter? string | nil
Query.find = function(session, collection, filter)
  local queryLines = {
    string.format("db['%s'].find({", collection),
  }

  if filter ~= nil then
    table.insert(queryLines, "  " .. filter)
  end
  table.insert(queryLines, "})")
  table.insert(queryLines, "  .limit(10)")
  table.insert(queryLines, "  .toArray()")

  buffer.set_query_content(session, { table.unpack(queryLines) })
  vim.cmd(":3")
end

return Query
