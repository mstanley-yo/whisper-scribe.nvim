local M = {}

function M.check()
  local health = vim.health or require("health")

  health.start("whisper-scribe.nvim")

  local ok, config = pcall(require, "whisper-scribe.config")
  local opts = ok and config.get() or nil

  local ffmpeg_path = (opts and opts.ffmpeg_path) or "ffmpeg"
  local whisper_cli_path = (opts and opts.whisper_cli_path) or "whisper-cli"

  if vim.fn.executable(ffmpeg_path) == 1 then
    health.ok(("ffmpeg found: %s"):format(ffmpeg_path))
  else
    health.error(("ffmpeg not found/executable: %s (see setup.sh, or brew install ffmpeg)"):format(ffmpeg_path))
  end

  if vim.fn.executable(whisper_cli_path) == 1 then
    health.ok(("whisper-cli found: %s"):format(whisper_cli_path))
  else
    health.error(
      ("whisper-cli not found/executable: %s (see setup.sh, or brew install whisper-cpp)"):format(whisper_cli_path)
    )
  end

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
