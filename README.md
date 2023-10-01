# mongo.nvim
Mongo client UI plugin for neovim


https://github.com/donus3/mongodb.nvim/assets/9076885/fde1991a-8e0b-4991-849e-8ce2436dd5da



## Installation

### Prerequisites
- mongodb shell ([mongosh](https://www.mongodb.com/docs/mongodb-shell/install/))
- (For mongo < 3.6) mongo ([mongo](https://www.mongodb.com/docs/v4.4/mongo/))

lazy.nvim
```lau
{
  "donus3/mongo.nvim",
  config = function()
    require("mongo").setup({
      default_url = "mongodb://localhost:9999",
    })
  end
}
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
})

```

## Keymaps

### Connection Workspace
|Keymap|Description|
|----|----|
|`<CR>`|Select/Confirm the context under cursor|
|`-`|Back to the previous menu|
|`gx`|Drop the collection under cursor|
|`gq`|Quit|

### Query Workspace
|Keymap|Description|
|----|----|
|`<CR>`|Execute the query under cursor|
|`gi`|Insert new query snippet|
|`gf`|Find the query snippet|
|`gu`|Update the query snippet|
|`gd`|Delete the query snippet|
|`gq`|Quit|

### Result Workspace
|Keymap|Description|
|----|----|
|`d`|Delete the document under cursor|
|`e`|Update the document under cursor|

## To-do
- [ ] Support multiple connections

## License

MIT License
