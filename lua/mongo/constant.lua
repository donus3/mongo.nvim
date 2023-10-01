local M = {}

M.state = {
  init = 1,
  connected = 2,
  db_selected = 3,
  collection_selected = 4,
}

M.host_example = "/** mongodb://user:pass@localhost:27017/?authSource=admin */"
M.host_fallback = "mongodb://localhost:27017"
M.mongodb_crud_page = "https://www.mongodb.com/docs/manual/crud/"

return M
