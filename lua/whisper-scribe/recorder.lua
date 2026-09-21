-- Thin vim.system() wrapper around ffmpeg mic recording.
local M = {}

local job = nil

--- Start recording mic audio (mono, 16kHz - what whisper.cpp expects) to
--- wav_path via ffmpeg's avfoundation input. on_exit is called via
--- vim.schedule, so it may safely call vim.api.*/vim.notify.
function M.start(wav_path, device_index, ffmpeg_path, on_exit)
  local cmd = {
    ffmpeg_path,
    "-y",
    "-f",
    "avfoundation",
    "-i",
    ":" .. tostring(device_index),
    "-ac",
    "1",
    "-ar",
    "16000",
    wav_path,
  }
  job = vim.system(cmd, { text = true }, function(obj)
    vim.schedule(function()
      on_exit(obj)
    end)
  end)
end

--- Gracefully stop the running recording (SIGINT, not SIGKILL, so ffmpeg
--- finalizes the WAV header/trailer instead of leaving a truncated file).
--- Returns false if no recording is currently running.
function M.stop()
  if not job then
    return false
  end
  job:kill("sigint")
  job = nil
  return true
end

return M
