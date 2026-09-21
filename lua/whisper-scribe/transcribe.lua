-- Thin vim.system() wrapper around whisper-cli.
local M = {}

--- Run whisper-cli on wav_path and return the result via on_exit (called
--- through vim.schedule, so it may safely call vim.api.*/vim.notify).
--- obj.stdout is the clean transcript text (-np -nt: no extra logging, no
--- timestamps, nothing else written to stdout).
function M.run(wav_path, model_path, language, on_exit)
  local cmd = {
    "whisper-cli",
    "-m",
    model_path,
    "-f",
    wav_path,
    "-l",
    language,
    "-np",
    "-nt",
  }
  vim.system(cmd, { text = true }, function(obj)
    vim.schedule(function()
      on_exit(obj)
    end)
  end)
end

return M
