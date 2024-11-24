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

M.check_error_from_response = check_error_from_response
return M
