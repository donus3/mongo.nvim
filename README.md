# mongo.nvim
Mongo client UI plugin for neovim (Work in progress!)

https://github.com/donus3/mongodb.nvim/assets/9076885/fde1991a-8e0b-4991-849e-8ce2436dd5da

## Installation

### Prerequisites
- mongodb shell ([mongosh](https://www.mongodb.com/docs/mongodb-shell/install/))
- (For mongo < 3.6) mongo ([mongo](https://www.mongodb.com/docs/v4.4/mongo/))

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
  find_on_collection_selected = false
  ---mongo binary path for mongodb < 3.6
  mongo_binary_path = nil,
  ---mongodb shell binary path
  mongosh_binary_path = "mongosh",
  ---number of documents in the result
  batch_size = 100,
})

```

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
