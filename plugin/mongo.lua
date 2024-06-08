vim.api.nvim_create_user_command("Mongo", function(command)
  require("mongo").connect(command.fargs)
end, {
  nargs = "*",
})
