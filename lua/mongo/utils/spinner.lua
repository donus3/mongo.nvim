local M = {}

local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local timer = nil
local spinner_index = 1
local bufnr = nil

function M.start_spinner(target_bufnr)
  if timer then
    return
  end -- Already running

  bufnr = target_bufnr or vim.api.nvim_get_current_buf()
  spinner_index = 1
  timer = vim.loop.new_timer()

  timer:start(
    0,
    100,
    vim.schedule_wrap(function()
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end

      local frame = spinner_frames[spinner_index]
      spinner_index = (spinner_index % #spinner_frames) + 1

      -- Overwrite the entire buffer with the spinner frame
      vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { frame .. " Fetching..." })
    end)
  )
end

function M.stop_spinner(message)
  if not timer then
    return
  end
  timer:stop()
  timer:close()
  timer = nil

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Replace spinner with final message (e.g. "✓ Done")
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { message or "✓ Done" })
end

return M
