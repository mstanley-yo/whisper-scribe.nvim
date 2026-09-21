local M = {}

--- Format a whole-second duration as "m:ss", e.g. 7 -> "0:07", 63 -> "1:03".
function M.format_duration(seconds)
  seconds = math.max(0, math.floor(seconds))
  local minutes = math.floor(seconds / 60)
  local secs = seconds % 60
  return ("%d:%02d"):format(minutes, secs)
end

return M
