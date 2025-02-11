local buffer = require("mongo.buffer")

---@class Query
local Query = {}

---snippet insertOne query
---@param workspace Workspace
---@param collection string
Query.insert_one = function(workspace, collection)
  local queryLines = {
    "begin",
    "",
    string.format("db['%s'].insertOne({", collection),
    "  ",
    "})",
    "",
    "end",
    "",
  }
  buffer.set_query_content(workspace, queryLines, true)
  vim.cmd(":5")
end

---snippet deleteOne query
---@param workspace Workspace
---@param collection string
---@param identifier? string | nil
Query.delete_one = function(workspace, collection, identifier)
  local queryLines = {
    "begin",
    "",
    string.format("db['%s'].deleteOne({", collection),
  }
  if identifier ~= nil then
    table.insert(queryLines, "  " .. identifier)
  else
    table.insert(queryLines, "  ")
  end
  table.insert(queryLines, "})")
  table.insert(queryLines, "")
  table.insert(queryLines, "end")
  table.insert(queryLines, "")
  buffer.set_query_content(workspace, queryLines, true)
  vim.cmd(":5")
end

---snippet updateOne query
---@param workspace Workspace
---@param collection string
---@param document? table<string[], string> | nil
Query.update_one = function(workspace, collection, document)
  local queryLines = {
    "begin",
    "",
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
  table.insert(queryLines, "")
  table.insert(queryLines, "end")
  table.insert(queryLines, "")

  buffer.set_query_content(workspace, queryLines, true)
  vim.cmd(":5")
end

---snippet find query
---@param workspace Workspace
---@param collection string
---@param filter? string | nil
Query.find = function(workspace, collection, filter)
  local queryLines = {
    "begin",
    "",
    string.format("db['%s'].find({", collection),
  }

  if filter ~= nil then
    table.insert(queryLines, "  " .. filter)
  end
  table.insert(queryLines, "})")
  table.insert(queryLines, "  .limit(10)")
  table.insert(queryLines, "  .toArray()")
  table.insert(queryLines, "")
  table.insert(queryLines, "end")
  table.insert(queryLines, "")

  buffer.set_query_content(workspace, queryLines)
  vim.cmd(":5")
end

return Query
