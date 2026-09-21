local M = {}

local defaults = {
  audio_device_index = nil, -- required: find via `ffmpeg -f avfoundation -list_devices true -i ""`
  model_path = nil, -- required: path to a ggml whisper.cpp model file
  max_line_width = 72,
  language = "en",
  ffmpeg_path = "ffmpeg", -- override if not on $PATH, e.g. a setup.sh-managed install
  whisper_cli_path = "whisper-cli", -- override if not on $PATH, e.g. a setup.sh-managed install
  status_ticker = true, -- periodic "Recording... 0:07" notify while recording/transcribing
}

local opts = nil

--- Validate and store user config. Hard-errors on missing/invalid required
--- fields so misconfiguration surfaces immediately at setup time rather than
--- failing silently on first use.
function M.setup(user_opts)
  local merged = vim.tbl_deep_extend("force", {}, defaults, user_opts or {})

  if type(merged.audio_device_index) ~= "number" then
    error(
      "[whisper-scribe.nvim] setup(): 'audio_device_index' is required (a number). "
        .. 'Find it via: ffmpeg -f avfoundation -list_devices true -i ""'
    )
  end

  if type(merged.model_path) ~= "string" or merged.model_path == "" then
    error("[whisper-scribe.nvim] setup(): 'model_path' is required (a string path to a ggml model file).")
  end

  local expanded_model_path = vim.fn.expand(merged.model_path)
  if vim.fn.filereadable(expanded_model_path) == 0 then
    error(("[whisper-scribe.nvim] setup(): model_path '%s' does not exist or is not readable."):format(
      expanded_model_path
    ))
  end
  merged.model_path = expanded_model_path

  -- vim.system() execs these directly with no shell, so a literal "~" would
  -- not be expanded and would fail - expand here regardless of whether the
  -- user configured a bare command name (e.g. "ffmpeg") or an absolute path.
  merged.ffmpeg_path = vim.fn.expand(merged.ffmpeg_path)
  merged.whisper_cli_path = vim.fn.expand(merged.whisper_cli_path)

  opts = merged
end

--- Returns the validated config, or nil (+ an error notify) if setup() was
--- never called.
function M.get()
  if opts == nil then
    vim.notify("[whisper-scribe.nvim] setup() has not been called yet.", vim.log.levels.ERROR)
    return nil
  end
  return opts
end

return M
