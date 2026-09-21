local M = {}

function M.check()
  local health = vim.health or require("health")

  health.start("whisper-scribe.nvim")

  if vim.fn.executable("ffmpeg") == 1 then
    health.ok("ffmpeg found on $PATH")
  else
    health.error("ffmpeg not found on $PATH (brew install ffmpeg)")
  end

  if vim.fn.executable("whisper-cli") == 1 then
    health.ok("whisper-cli found on $PATH")
  else
    health.error("whisper-cli not found on $PATH (brew install whisper-cpp)")
  end

  local ok, config = pcall(require, "whisper-scribe.config")
  local opts = ok and config.get() or nil

  if not opts then
    health.error("setup() has not been called (or failed) - see README for required options")
    return
  end

  health.ok("setup() has been called")

  if vim.fn.filereadable(opts.model_path) == 1 then
    health.ok(("model_path is readable: %s"):format(opts.model_path))
  else
    health.error(("model_path is not readable: %s"):format(opts.model_path))
  end

  if type(opts.audio_device_index) == "number" then
    health.ok(("audio_device_index is set to %d"):format(opts.audio_device_index))
    health.info(
      'this cannot be verified as correct automatically - re-check with `ffmpeg -f avfoundation -list_devices true -i ""` if audio hardware has changed'
    )
  else
    health.error("audio_device_index is not set")
  end

  health.info(
    "macOS microphone permission (TCC) cannot be checked here - the permission prompt only fires on the first real recording attempt. If recordings come back empty, check System Settings > Privacy & Security > Microphone for your terminal app."
  )
end

return M
