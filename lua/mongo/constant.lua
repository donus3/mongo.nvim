local Constant = {}

Constant.state = {
  init = 1,
  connected = 2,
  db_selected = 3,
  collection_selected = 4,
}

Constant.host_example = "/** mongodb://user:pass@localhost:27017/?authSource=admin */"
Constant.host_fallback = "mongodb://localhost:27017"
Constant.mongodb_crud_page = "https://www.mongodb.com/docs/manual/crud/"

Constant.command_buf_name = "MongoDB Working Space "
Constant.result_buf_name = "MongoDB Query Results "
Constant.connection_buf_name = "MongoDB Connection "

return Constant
