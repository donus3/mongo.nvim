local ss = require("mongo.session")

---@class Client
local Client = {}

---check_is_legacy_async check if the host is legacy or not
---@param session Session
---@param cb fun()
Client.check_is_legacy_async = function(session, cb)
  local host = ss.get_host(session.name)
  local full_cmd = {
    "mongosh",
    host,
    "--authenticationDatabase",
    session.auth_source,
    "--quiet",
  }

  vim.system(full_cmd, { text = true }, function(out)
    if out.stderr:find("MongoServerSelectionError") then
      ss.set_session_field(session.name, "is_legacy", true)
    else
      ss.set_session_field(session.name, "is_legacy", false)
    end
    cb()
  end)
end

---run_command run mongosh or mongo with given args asynchronously
---@param session Session
---@param args string eval string arguments pass the mongosh
---@param on_exit fun(out: {code: number, stdout: string, stderr: string}) cb function to call after the command is done
Client.run_async_command = function(session, args, on_exit)
  vim.defer_fn(function()
    -- disable the back keymaps while running the command
    vim.keymap.set("n", "-", "", { buffer = session.connection_buf })
  end, 0)

  local host = ss.get_host(session.name)
  local cmd = "mongosh"
  if session.is_legacy then
    cmd = "mongo"
  end

  local full_cmd = {
    cmd,
    host,
    "--authenticationDatabase",
    session.auth_source,
    "--quiet",
    "--eval",
    args,
  }

  if session.username ~= nil and session.password ~= nil then
    table.insert(full_cmd, "-u")
    table.insert(full_cmd, session.username)
    table.insert(full_cmd, "-p")
    table.insert(full_cmd, session.password)
  end

  return vim.system(full_cmd, { text = true }, function(out)
    print(vim.inspect(out))
    on_exit(out)
  end)
end

return Client
