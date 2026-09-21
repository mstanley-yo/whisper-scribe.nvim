-- Thin vim.system() wrapper around whisper-cli.
local M = {}

local job = nil

--- Run whisper-cli on wav_path and return the result via on_exit (called
--- through vim.schedule, so it may safely call vim.api.*/vim.notify).
--- obj.stdout is the clean transcript text (-np -nt: no extra logging, no
--- timestamps, nothing else written to stdout).
function M.run(wav_path, model_path, language, whisper_cli_path, on_exit)
  local cmd = {
    whisper_cli_path,
    "-m",
    model_path,
    "-f",
    wav_path,
    "-l",
    language,
    "-np",
    "-nt",
  }
  job = vim.system(cmd, { text = true }, function(obj)
    vim.schedule(function()
      on_exit(obj)
    end)
  end)
end

--- Kill the running whisper-cli process. No file to finalize gracefully
--- (unlike ffmpeg's WAV header), so an immediate kill is fine. Returns
--- false if no transcription is currently running.
function M.cancel()
  if not job then
    return false
  end
  job:kill("sigkill")
  job = nil
  return true
end

return M
