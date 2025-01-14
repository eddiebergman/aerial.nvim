local backends = require("aerial.backends")
local backend_util = require("aerial.backends.util")
local util = require("aerial.util")

local M = {}

M.is_supported = function(bufnr)
  if not vim.tbl_contains(util.get_filetypes(bufnr), "markdown") then
    return false, "Filetype is not markdown"
  end
  return true, nil
end

M.fetch_symbols_sync = function(timeout)
  local extensions = require("aerial.backends.treesitter.extensions")
  local bufnr = 0
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
  local items = {}
  local stack = {}
  local inside_code_block = false
  for lnum, line in ipairs(lines) do
    local idx, len = string.find(line, "^#+ ")
    if idx == 1 and not inside_code_block then
      local level = len - 2
      local parent = stack[math.min(level, #stack)]
      local item = {
        kind = "Interface",
        name = string.sub(line, len + 1),
        level = level,
        parent = parent,
        lnum = lnum,
        col = 0,
      }
      if parent then
        if not parent.children then
          parent.children = {}
        end
        table.insert(parent.children, item)
      else
        table.insert(items, item)
      end
      while #stack > level and #stack > 0 do
        table.remove(stack, #stack)
      end
      table.insert(stack, item)
    elseif string.find(line, "```") == 1 then
      inside_code_block = not inside_code_block
    end
  end
  -- This sets the proper end_lnum and end_col
  extensions.markdown.postprocess_symbols(bufnr, items)
  backends.set_symbols(bufnr, items)
end

M.fetch_symbols = M.fetch_symbols_sync

M.attach = function(bufnr)
  backend_util.add_change_watcher(bufnr, "markdown")
  M.fetch_symbols()
end

M.detach = function(bufnr)
  backend_util.remove_change_watcher(bufnr, "markdown")
end

return M
