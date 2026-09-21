# whisper-scribe.nvim

Local, offline push-to-toggle dictation for Neovim. Press a key to start
recording your microphone, press it again to stop - the transcript is
appended to the end of the current buffer, reformatted to one sentence per
line, wrapped so no line exceeds 72 characters (splitting on commas first,
falling back to word-wrapping).

No cloud APIs, no GUI automation. `ffmpeg` records to a temporary WAV file;
[whisper.cpp](https://github.com/ggml-org/whisper.cpp)'s `whisper-cli`
transcribes it once when you stop recording.

macOS only (uses ffmpeg's `avfoundation` input). Requires Apple Silicon for
whisper.cpp's Metal acceleration to be worthwhile, though the CPU path works
on any arch.

## Prerequisites

```sh
brew install ffmpeg whisper-cpp
```

Download a model (this is a one-off manual step, not automated by the
plugin - pick whichever size you like from
[ggerganov/whisper.cpp on Hugging Face](https://huggingface.co/ggerganov/whisper.cpp)):

```sh
mkdir -p ~/.local/share/nvim/whisper-scribe/models
curl -L https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin \
  -o ~/.local/share/nvim/whisper-scribe/models/ggml-base.en.bin
```

`base.en` is a good speed/accuracy balance on Apple Silicon. `tiny.en` is
faster but less accurate; `small.en` is slower but more accurate.

Find your microphone's `avfoundation` device index (it's machine-specific,
and can shift if you plug in a different mic):

```sh
ffmpeg -f avfoundation -list_devices true -i ""
```

Look under "AVFoundation audio devices" for the index of your mic.

## Install (lazy.nvim)

```lua
{
  "your-github-username/whisper-scribe.nvim",
  keys = {
    { "<leader>W", "<cmd>WhisperScribe<cr>", desc = "Toggle voice dictation" },
  },
  opts = {
    audio_device_index = 0, -- from `ffmpeg -f avfoundation -list_devices true -i ""`
    model_path = "~/.local/share/nvim/whisper-scribe/models/ggml-base.en.bin",
  },
}
```

The plugin deliberately does not set its own keymap - bind `:WhisperScribe`
(or `require("whisper-scribe").toggle()`) to whatever key you like, as shown
above. `<leader>W` (capital W) doesn't collide with LazyVim's `<leader>w`
window-management group, since keymaps are case-sensitive.

## Configuration

| Option | Type | Default | Required |
|---|---|---|---|
| `audio_device_index` | number | - | yes, no safe default |
| `model_path` | string | - | yes, no safe default |
| `max_line_width` | number | `72` | no |
| `language` | string | `"en"` | no |

`audio_device_index` and `model_path` hard-error at `setup()` time if
missing or invalid, so misconfiguration surfaces immediately via lazy.nvim's
own error reporting rather than failing silently later.

## Usage

- Press your configured key (e.g. `<leader>W`) → "recording started" notify.
  Recording runs in the background; the editor stays responsive.
- Speak.
- Press the same key again → "recording stopped, transcribing..." notify.
- A few seconds later, the transcript appears at the end of the buffer that
  was current when you started recording (even if you've since switched
  buffers/windows), one sentence per line, wrapped at 72 characters.
- Pressing the key again while still transcribing does nothing but warn -
  it won't spawn a second recording.

## Health check

Run `:checkhealth whisper-scribe` to verify `ffmpeg` and `whisper-cli` are on
`$PATH`, `setup()` has been called, and `model_path` is readable. It cannot
verify that `audio_device_index` is actually correct (re-run the
`list_devices` command above if your audio hardware changes) or that macOS
has granted microphone permission - that prompt only appears the first time
you actually record, and there's no way to check or trigger it ahead of time.

## Troubleshooting

- **"recording failed (ffmpeg exited unexpectedly...)"**: usually a wrong
  `audio_device_index`, or the terminal app hasn't been granted microphone
  access in System Settings > Privacy & Security > Microphone.
- **"no audio captured"**: the WAV file came back empty/near-empty - check
  the device index and mic permission.
- **"transcription produced no text"**: whisper-cli ran successfully but
  detected only silence.
- **"transcription failed (whisper-cli exited...)"**: check `model_path`
  points at a real ggml model file; the WAV file is deliberately left on
  disk (path included in the error) for debugging in this case.

## Running tests

Only `format.lua` (the sentence-splitting/wrapping logic) is unit-tested -
recording and transcription depend on real hardware and aren't mocked.
Requires [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) to already
be installed (e.g. via your normal plugin manager):

```sh
nvim --headless -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"
```

## Manual verification checklist

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
