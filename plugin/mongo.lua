vim.api.nvim_create_user_command("Mongo", require("mongo").connect, {})
