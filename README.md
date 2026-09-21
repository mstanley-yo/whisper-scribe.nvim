# whisper-scribe.nvim

Local, offline push-to-toggle dictation for Neovim. Press a key to start
recording your microphone, press it again to stop - the transcript is
appended to the end of the current buffer, one sentence per line. macOS only.

## Installation

**1. Add the plugin** (using [lazy.nvim](https://github.com/folke/lazy.nvim)
- create `lua/plugins/whisper-scribe.lua` in your Neovim config with this
content):

```lua
return {
  "mstanley-yo/whisper-scribe.nvim",
  keys = {
    { "<leader>vw", "<cmd>WhisperScribe<cr>", desc = "Toggle voice dictation" },
    { "<leader>vc", "<cmd>WhisperScribeCancel<cr>", desc = "Cancel voice dictation" },
  },
  opts = {
    audio_device_index = 0, -- you'll set this for real in step 3
    model_path = "~/.local/share/whisper-scribe/models/ggml-base.en.bin",
    whisper_cli_path = "~/.local/share/whisper-scribe/bin/whisper-cli",
  },
}
```

**2. Restart Neovim** (or run `:Lazy sync`) so lazy.nvim downloads the
plugin.

**3. Run the setup script.** This installs everything the plugin needs
(`ffmpeg`, the `whisper-cli` speech-recognition engine, and a speech model)
and is safe to re-run any time. Open a terminal and run:

```sh
~/.local/share/nvim/lazy/whisper-scribe.nvim/setup.sh
```

Near the end it prints a list of your computer's microphones, each with a
number, e.g. `[0] MacBook Pro Microphone`. Take that number and put it in
`audio_device_index` in the config from step 1, then save the file.

**4. Restart Neovim once more.** You're done - press `<leader>vw` to try it.

## Usage

- Press `<leader>vw` → a notification confirms recording has started.
- Speak. A notification keeps ticking with the elapsed time
  ("recording... 0:07") so you can tell it's still going.
- Press `<leader>vw` again → the notification switches to "transcribing...",
  still ticking.
- A few seconds later, the transcript appears at the end of your buffer, and
  the notification reports how many lines were inserted.
- Changed your mind, or triggered it by accident? Press `<leader>vc` at any
  point during recording or transcribing to cancel - the recording is
  discarded and nothing is inserted. Pressing it while idle just says
  "nothing to cancel."

If your notification plugin supports updating a message in place (e.g.
[snacks.nvim](https://github.com/folke/snacks.nvim)'s notifier), that whole
sequence appears as one message that evolves over time rather than a pile of
separate popups - no extra setup needed, the plugin doesn't depend on snacks
or any other notifier, it just cooperates with whatever `vim.notify` you have.

## Configuration

| Option | Type | Default | Required |
|---|---|---|---|
| `audio_device_index` | number | - | yes |
| `model_path` | string | - | yes |
| `whisper_cli_path` | string | `"whisper-cli"` | no (set by `setup.sh`'s example above) |
| `ffmpeg_path` | string | `"ffmpeg"` | no |
| `max_line_width` | number | `72` | no |
| `language` | string | `"en"` | no |
| `status_ticker` | boolean | `true` | no |

`audio_device_index` and `model_path` produce a clear error on startup if
missing or invalid. Set `status_ticker = false` to turn off the
periodic "recording/transcribing... elapsed time" notifications and only get
the start/stop/result messages.

### Statusline

`require("whisper-scribe").status()` returns `"idle"`, `"recording"`, or
`"transcribing"`; `require("whisper-scribe").elapsed()` returns seconds in
the current state (or `nil` when idle). Example lualine component:

```lua
{
  function()
    local ws = require("whisper-scribe")
    local elapsed = ws.elapsed()
    if not elapsed then
      return ""
    end
    local mins, secs = math.floor(elapsed / 60), elapsed % 60
    local icon = ws.status() == "recording" and "🎙" or "…"
    return ("%s %d:%02d"):format(icon, mins, secs)
  end,
}
```

## Health check

Run `:checkhealth whisper-scribe` to verify `ffmpeg` and `whisper-cli` can be
found and the model file is readable. It can't verify that
`audio_device_index` is still correct (re-run step 3's `setup.sh` if you plug
in a different microphone) or that macOS has granted microphone access -
that permission prompt only appears the first time you actually record.

## Troubleshooting

- **Nothing happens / "command not found" errors**: re-run
  `setup.sh` (step 3) - it's safe to run multiple times and will fix a
  broken `ffmpeg` install automatically.
- **"recording failed (ffmpeg exited unexpectedly...)"**: usually a wrong
  `audio_device_index`, or the terminal app hasn't been granted microphone
  access in System Settings > Privacy & Security > Microphone.
- **"no audio captured"**: the recording came back empty - check the device
  index and mic permission above.
- **"transcription produced no text"**: it ran successfully but only heard
  silence.
- **"transcription failed"**: check `model_path` points at a real file (the
  recording is deliberately kept on disk in this case - the path is in the
  error message - for debugging).

## Development

Only `format.lua` (the sentence-splitting/wrapping logic) is unit-tested -
recording and transcription depend on real hardware and aren't mocked.
Requires [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) to already
be installed:

```sh
nvim --headless -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"
```

Manual end-to-end checklist:

1. `:checkhealth whisper-scribe` - all green (aside from the informational
   notes above).
2. `:WhisperScribe` on a scratch buffer → "recording started" notify appears
   immediately, editor stays responsive.
3. Speak one long sentence with several commas, and one long sentence with
   no commas at all.
4. `:WhisperScribe` again → "recording stopped, transcribing..." notify;
   editor stays responsive during the whisper-cli run.
5. Transcript lands at the end of the buffer: one sentence per line, no line
   over 72 characters, commas preferred over word-wrap where they fit.
6. Switch to a different buffer/window while transcription is still running
   → confirm the transcript still lands in the *original* buffer.
7. Start a recording, then close/delete that buffer before stopping/before
   transcription completes → confirm a "target buffer no longer valid"
   warning fires with the transcript text included, no crash.
8. Press the toggle key three times in quick succession → "still
   transcribing previous recording" warning on the extra presses, no second
   ffmpeg/whisper-cli process spawned.
9. Failure paths: set `audio_device_index` to a bogus value → clean
   ffmpeg-failed error, resets to idle. Set `model_path` to a nonexistent
   file → hard error at `setup()`. Record ~1s of silence → "no text"
   warning, nothing inserted.
10. Confirm the ticking notifications appear roughly once per second while
    recording and while transcribing, and that with a replace-capable
    notifier (e.g. snacks.nvim) they update one message in place rather than
    stacking; with plain built-in `vim.notify` they should just echo in
    turn with no errors.
11. Set `opts.status_ticker = false` → confirm the periodic messages stop
    but the start/stop/result notifications still fire normally.
12. `<leader>vw` to start, then `<leader>vc` mid-recording → "canceling..."
    then "recording canceled", back to idle, nothing inserted.
13. `<leader>vw` to start, speak, `<leader>vw` to stop, then `<leader>vc`
    while it's transcribing → "transcription canceled" (not reported as a
    failure), back to idle, nothing inserted.
14. `<leader>vc` while idle → "nothing to cancel.", no errors.
