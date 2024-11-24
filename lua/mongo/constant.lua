local Constant = {}

Constant.host_example = "/** mongodb://user:pass@localhost:27017/?authSource=admin */"
Constant.host_fallback = "mongodb://localhost:27017"
Constant.mongodb_crud_page = "https://www.mongodb.com/docs/manual/crud/"

Constant.workspace = "Workspace: "
Constant.query_buf_name = " Query for database: "
Constant.result_buf_name = " Results"
Constant.connection_buf_name = " Connection"
Constant.collection_buf_name = " Collections"
Constant.database_buf_name = " Databases"

return Constant
