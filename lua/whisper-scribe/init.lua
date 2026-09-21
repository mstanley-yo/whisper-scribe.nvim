local config = require("whisper-scribe.config")
local recorder = require("whisper-scribe.recorder")
local transcribe = require("whisper-scribe.transcribe")
local format = require("whisper-scribe.format")

local M = {}

local STATE_IDLE = "idle"
local STATE_RECORDING = "recording"
local STATE_TRANSCRIBING = "transcribing"

local state = STATE_IDLE
local bufnr = nil
local wav_path = nil
local stop_requested = false
local cancel_requested = false
local state_started_at = nil
local status_timer = nil

-- Every notification shares one id. Backends that support replacing a
-- notification in place by id (e.g. snacks.nvim's notifier, which works by
-- globally replacing vim.notify) will collapse a whole recording ->
-- transcribing -> done lifecycle into one evolving message. Plain built-in
-- vim.notify ignores the unrecognized opts.id field and just echoes each
-- call as it already does today - no special-casing needed either way.
local function notify(msg, level)
  vim.notify("[whisper-scribe] " .. msg, level or vim.log.levels.INFO, { id = "whisper-scribe-status" })
end

local function mark_state_started()
  state_started_at = os.time()
end

local function tick()
  if state == STATE_IDLE then
    return
  end
  local opts = config.get()
  if not opts or not opts.status_ticker then
    return
  end
  local elapsed = format.format_duration(os.time() - state_started_at)
  if state == STATE_RECORDING then
    notify(("recording... %s"):format(elapsed))
  elseif state == STATE_TRANSCRIBING then
    notify(("transcribing... %s"):format(elapsed))
  end
  vim.cmd("redrawstatus")
end

local function start_ticker(opts)
  if not opts.status_ticker or status_timer then
    return
  end
  status_timer = vim.uv.new_timer()
  status_timer:start(1000, 1000, vim.schedule_wrap(tick))
end

local function stop_ticker()
  if not status_timer then
    return
  end
  status_timer:stop()
  status_timer:close()
  status_timer = nil
end

local function reset()
  state = STATE_IDLE
  bufnr = nil
  wav_path = nil
  stop_requested = false
  cancel_requested = false
  state_started_at = nil
  stop_ticker()
end

local function start_transcription()
  local opts = config.get()
  if not opts then
    reset()
    return
  end

  transcribe.run(wav_path, opts.model_path, opts.language, opts.whisper_cli_path, function(obj)
    local path_for_cleanup = wav_path

    if cancel_requested then
      os.remove(path_for_cleanup)
      notify("transcription canceled.")
      reset()
      return
    end

    if obj.code ~= 0 then
      notify(
        ("transcription failed (whisper-cli exited %d): %s"):format(obj.code, obj.stderr or ""),
        vim.log.levels.ERROR
      )
      -- deliberately not deleting the WAV file here - left on disk for debugging
      reset()
      return
    end

    local text = (obj.stdout or ""):match("^%s*(.-)%s*$")
    if text == "" then
      notify("transcription produced no text (silence or inaudible audio).", vim.log.levels.WARN)
      os.remove(path_for_cleanup)
      reset()
      return
    end

    local lines = format.format_transcript(text, opts.max_line_width)

    if vim.api.nvim_buf_is_valid(bufnr) then
      local last = vim.api.nvim_buf_line_count(bufnr)
      vim.api.nvim_buf_set_lines(bufnr, last, last, false, lines)
      notify(("transcript inserted (%d line%s)."):format(#lines, #lines == 1 and "" or "s"))
    else
      notify(
        "target buffer no longer valid; transcript discarded:\n" .. table.concat(lines, "\n"),
        vim.log.levels.WARN
      )
    end

    os.remove(path_for_cleanup)
    reset()
  end)
end

local function on_ffmpeg_exit(obj)
  if cancel_requested then
    if wav_path then
      os.remove(wav_path)
    end
    notify("recording canceled.")
    reset()
    return
  end

  if not stop_requested then
    -- ffmpeg died on its own while we were still recording (bad device
    -- index, permission denial, etc.) - this is a real failure.
    notify(
      ("recording failed (ffmpeg exited unexpectedly, code=%d): %s"):format(obj.code, obj.stderr or ""),
      vim.log.levels.ERROR
    )
    reset()
    return
  end

  -- We asked ffmpeg to stop via SIGINT; it doesn't reliably exit 0 across
  -- versions, so judge success by the resulting file instead of the code.
  local stat = vim.uv.fs_stat(wav_path)
  if not stat or stat.size <= 44 then
    notify("no audio captured (recording too short, or device produced no data).", vim.log.levels.WARN)
    reset()
    return
  end

  state = STATE_TRANSCRIBING
  mark_state_started()
  start_transcription()
end

local function start_recording()
  local opts = config.get()
  if not opts then
    return
  end

  bufnr = vim.api.nvim_get_current_buf()
  wav_path = vim.fn.tempname() .. ".wav"
  stop_requested = false

  recorder.start(wav_path, opts.audio_device_index, opts.ffmpeg_path, on_ffmpeg_exit)
  state = STATE_RECORDING
  mark_state_started()
  start_ticker(opts)
  notify("recording started")
end

local function stop_recording()
  stop_requested = true
  recorder.stop()
  notify("recording stopped, transcribing...")
end

--- Configure the plugin. See README for available options. Required:
--- audio_device_index (number), model_path (string).
function M.setup(opts)
  config.setup(opts)
end

--- Start recording if idle, stop (and transcribe) if recording, or warn if
--- a previous recording is still being transcribed.
function M.toggle()
  if state == STATE_IDLE then
    start_recording()
  elseif state == STATE_RECORDING then
    stop_recording()
  else
    notify("still transcribing previous recording, please wait.", vim.log.levels.WARN)
  end
end

--- Abort whatever is currently happening (recording or transcribing) and
--- discard it - no text is inserted. No-ops with a notice if already idle.
function M.cancel()
  if state == STATE_IDLE then
    notify("nothing to cancel.")
    return
  end

  cancel_requested = true
  notify("canceling...")

  if state == STATE_RECORDING then
    recorder.stop()
  else
    transcribe.cancel()
  end
end

--- Returns "idle" | "recording" | "transcribing".
function M.status()
  return state
end

--- Returns seconds elapsed in the current state, or nil if idle.
function M.elapsed()
  if state == STATE_IDLE or not state_started_at then
    return nil
  end
  return os.time() - state_started_at
end

return M
