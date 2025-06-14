M = {}

---@param response string
---@return { ok: boolean }
local check_error_from_response = function(response)
  if response == nil then
    vim.defer_fn(function()
      vim.notify("expected json but the response is nil", vim.log.levels.WARN)
    end, 0)
    return { ok = false }
  end

  if response:match("^Mongo") then
    vim.defer_fn(function()
      vim.notify(response, vim.log.levels.WARN)
    end, 0)
    return { ok = false }
  end

  return { ok = true }
end

-- Function to parse MongoDB URI components
---@param uri string mongo URI
M.extract_input_uri = function(uri)
  local components = {}

  -- Remove mongodb:// prefix
  local cleaned_uri = uri:gsub("^mongodb://", "")

  -- Extract credentials (username:password@)
  local credentials, rest = cleaned_uri:match("^([^@]+)@(.+)$")
  if credentials then
    components.username, components.password = credentials:match("^([^:]+):(.+)$")
    cleaned_uri = rest
  else
    cleaned_uri = cleaned_uri
  end

  -- Split by '?' to separate connection string from query parameters
  local connection_part, query_part = cleaned_uri:match("^([^?]+)%?(.*)$")
  if not connection_part then
    connection_part = cleaned_uri
    query_part = ""
  end

  -- Extract database name and hosts
  local hosts_part, database = connection_part:match("^(.+)/(.+)$")
  if hosts_part then
    components.selected_database = database

    local hostname, port = hosts_part:match("^([^:]+):?(%d*)$")
    components.host = hostname
    if port ~= nil and port ~= "" then
      components.host = components.host .. ":" .. port
    end
  else
    -- No database specified
    local hostname, port = connection_part:match("^([^:]+):?(%d*)/?$")
    components.host = hostname
    if port ~= nil and port ~= "" then
      components.host = components.host .. ":" .. port
    end
  end

  if components.host == nil then
    vim.defer_fn(function()
      vim.notify(
        "Unsupported mongodb URI "
        .. uri
        .. ". Please use mongodb://username:password@host[/db_name][/?options] or mongodb://host[/db_name][/?options]",
        vim.log.levels.ERROR
      )
    end, 0)
  end

  -- Parse query parameters
  components.options = {}
  if query_part ~= "" then
    for param in query_part:gmatch("[^&]+") do
      local key, value = param:match("^([^=]+)=(.*)$")
      if key and value then
        -- URL decode if needed (basic implementation)
        value = value:gsub("%%(%x%x)", function(hex)
          return string.char(tonumber(hex, 16))
        end)
        components.options[key] = value
      end
    end
  end

  return components
end

M.check_error_from_response = check_error_from_response
return M
