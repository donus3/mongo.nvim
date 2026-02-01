# mongo.nvim
Mongo client UI plugin for neovim (Work in progress!)

https://github.com/donus3/mongodb.nvim/assets/9076885/fde1991a-8e0b-4991-849e-8ce2436dd5da

## Installation

### Prerequisites
- mongodb shell ([mongosh](https://www.mongodb.com/docs/mongodb-shell/install/)) - used for modern MongoDB (>= v3.6)
- (OPTIONAL For mongo < v3.6) mongo legacy ([mongo](https://www.mongodb.com/docs/v4.4/mongo/)) - used for legacy servers

lazy.nvim
```lua
{
  "donus3/mongo.nvim",
  dependencies = {
    "ibhagwan/fzf-lua"
  },
  config = function()
    require("mongo").setup()
  end
}
```

## Usage
```vim
# explicitly session name
:Mongo <session-name>

# randomly generate a session name (math.random)
:Mongo
```

## Features

- Support mongodb version < 3.6 and >= 3.6
- Using URI connection
- CRUD queries and aggregate
- Tree-Sitter for document updating and deletion
- Intuitive UI

## Default Configuration
```lua
  require("mongo").setup({
  ---default mongo url show on start up
  default_url = "mongodb://localhost:27017",
  ---execute query on collection selected 
  find_on_collection_selected = false,
  ---binary path for mongodb < v3.6 (legacy) and fallback
  mongo_binary_path = nil,
  ---binary path for modern mongodb shell (mongosh)
  mongosh_binary_path = "mongosh",
  ---number of documents in the result
  batch_size = 100,
})

```

### Binary Selection & Fallback
The plugin automatically selects the appropriate binary based on the server version and availability:
- **`mongosh_binary_path`**: The default binary for modern MongoDB servers (>= v3.6).
- **`mongo_binary_path`**: Used explicitly for legacy servers (< v3.6).
- **Fallback**: If `mongosh_binary_path` is not executable or found on your system, the plugin will automatically attempt to use `mongo_binary_path` as a fallback.
- If no binary is found, an error notification will be displayed.

### Query
In the query workspace, you can only execute queries in range by surrounding the query with `begin` and `end` 
scope declaration.

```js
// first scope
begin

// if the cursor on this line, Enter key press won't execute the second scope
db.collection.find({ key: 'bar' }) 

end

// second scope
begin

db.collection.find({ key: 'foo' })

end
```

If there is no `begin` and `end` scope, the whole query will be executed.

## Keymaps

### Session Workspace
|Keymap|Description|
|--------|-----|
|`gq`|Quit|

### Connection Workspace
|Keymap|Description|
|--------|----|
|`<CR>`| Connect to the mongo server|

### Database Workspace
|Keymap|Description|
|--------|-----------------------------------|
|`<CR>`|Select the database|
|`<C-r>`|Refresh database list|
|`gx`|Drop the collection under cursor|

### Query Workspace
|Keymap|Description|
|--------|-----------------------------------|
|`<CR>`|Execute the query under cursor|
|`gi`|Insert new query snippet|
|`gf`|Find the query snippet|
|`gu`|Update the query snippet|
|`gd`|Delete the query snippet|

### Result Workspace
|Keymap|Description|
|----------|----------------------------------|
|`d`|Delete the document under cursor|
|`e`|Update the document under cursor|

## To-do
- [ ] Save session
- [ ] Save queries
- [ ] export results in json, csv
- [ ] dump collection and database
- [ ] import collection and database
- [ ] export API

## License

MIT License
