# mongo.nvim
Mongo client UI plugin for neovim (Work in progress!)

https://github.com/donus3/mongodb.nvim/assets/9076885/fde1991a-8e0b-4991-849e-8ce2436dd5da

## Installation

### Prerequisites
- [Node.js](https://nodejs.org/) - required for the MongoDB driver executor
- (Optional) [mongosh](https://www.mongodb.com/docs/mongodb-shell/install/) - for legacy fallback or external shell access

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
  ---binary path for node
  node_binary_path = "node",
  ---automatically install node dependencies on load
  auto_install = true,
  ---number of documents in the result
  batch_size = 100,
  ---version of the mongodb node driver
  mongodb_driver_version = "^7.0.0",
})

```

### Executor Implementation
The plugin now uses a Node.js-based executor with the official MongoDB driver. This removes the dependency on `mongosh` or `mongo` binaries.

**Automatic Dependency Installation**: By default, the plugin will automatically run `npm install` in its `node` directory if the MongoDB driver is not found. This behavior can be disabled by setting `auto_install = false` in the configuration.

**Custom Driver Version**: You can specify a custom version of the MongoDB Node.js driver using the `mongodb_driver_version` option. The plugin will automatically ensure the correct version is installed if it deviates from the current installation.

### New Database and Collection

1. In the database/collection buffer, add a new line with no indentation to create a new database.
2. Add another new line indented by one level under that database to create a collection.

**Committing the database and collection**

1. To commit the database and collection, you must insert at least one document:
2. Move your cursor to the collection line.
3. Open the query buffer.
4.Insert a document.
5.Press Enter to submit it.

Once a document is inserted, the database and collection will be committed.

### Query
In the query buffer, you can only execute queries in range by surrounding the query with `begin` and `end` 
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
