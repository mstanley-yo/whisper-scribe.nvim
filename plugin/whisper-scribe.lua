if vim.g.loaded_whisper_scribe then
  return
end
vim.g.loaded_whisper_scribe = true

vim.api.nvim_create_user_command("WhisperScribe", function()
  require("whisper-scribe").toggle()
end, {
  desc = "Toggle local voice-to-text recording (whisper-scribe.nvim)",
})

vim.api.nvim_create_user_command("WhisperScribeCancel", function()
  require("whisper-scribe").cancel()
end, {
  desc = "Cancel/discard the current recording or transcription (whisper-scribe.nvim)",
})
