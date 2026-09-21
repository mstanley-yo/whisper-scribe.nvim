-- Pure text formatting: split a transcript into sentences, one per line,
-- wrapping any sentence over max_width first on commas, then on words.
local M = {}

--- Split text into sentences on . ! ? followed by whitespace or end-of-string.
--- Runs of terminators (e.g. "?!", "...") are treated as a single boundary.
--- A terminator NOT followed by whitespace/EOS (e.g. the "." in "3.14") does
--- not split.
function M.split_sentences(text)
  local sentences, start_idx, len, i = {}, 1, #text, 1
  while i <= len do
    local c = text:sub(i, i)
    if c == "." or c == "!" or c == "?" then
      local j = i
      while j <= len and text:sub(j, j):match("[.!?]") do
        j = j + 1
      end
      if j > len or text:sub(j, j):match("%s") then
        table.insert(sentences, text:sub(start_idx, j - 1))
        while j <= len and text:sub(j, j):match("%s") do
          j = j + 1
        end
        start_idx, i = j, j
      else
        i = i + 1
      end
    else
      i = i + 1
    end
  end
  if start_idx <= len then
    table.insert(sentences, text:sub(start_idx, len))
  end

  local result = {}
  for _, s in ipairs(sentences) do
    s = s:match("^%s*(.-)%s*$")
    if s ~= "" then
      table.insert(result, s)
    end
  end
  return result
end

--- Greedily merge tokens into lines, starting a new line whenever appending
--- the next token (joined by join_sep) would exceed max_width. A line can
--- only end up over max_width if a single input token already was.
function M.pack_greedy(tokens, join_sep, max_width)
  local lines, current = {}, nil
  for _, token in ipairs(tokens) do
    if current == nil then
      current = token
    else
      local candidate = current .. join_sep .. token
      if #candidate <= max_width then
        current = candidate
      else
        table.insert(lines, current)
        current = token
      end
    end
  end
  if current ~= nil then
    table.insert(lines, current)
  end
  return lines
end

--- Split text on a literal delimiter character, keeping the delimiter
--- attached to the preceding token, and trimming whitespace after it.
function M.split_keep_delim(text, delim)
  local tokens, start_idx, len = {}, 1, #text
  while start_idx <= len do
    local d = text:find(delim, start_idx, true)
    if not d then
      table.insert(tokens, text:sub(start_idx))
      break
    end
    table.insert(tokens, text:sub(start_idx, d))
    start_idx = d + 1
    while start_idx <= len and text:sub(start_idx, start_idx):match("%s") do
      start_idx = start_idx + 1
    end
  end
  return tokens
end

--- Split text on whitespace into words.
function M.split_words(text)
  local words = {}
  for w in text:gmatch("%S+") do
    table.insert(words, w)
  end
  return words
end

--- Wrap a single sentence: pack on comma-clauses first; any resulting line
--- still over max_width (including the no-commas-at-all case, where the
--- comma-split degenerates to one token equal to the whole sentence) falls
--- back to word-wrapping that line.
function M.wrap_sentence(sentence, max_width)
  max_width = max_width or 72
  local packed = M.pack_greedy(M.split_keep_delim(sentence, ","), " ", max_width)
  local lines = {}
  for _, line in ipairs(packed) do
    if #line <= max_width then
      table.insert(lines, line)
    else
      for _, wrapped in ipairs(M.pack_greedy(M.split_words(line), " ", max_width)) do
        table.insert(lines, wrapped)
      end
    end
  end
  return lines
end

--- Format a whole-second duration as "m:ss", e.g. 7 -> "0:07", 63 -> "1:03".
function M.format_duration(seconds)
  seconds = math.max(0, math.floor(seconds))
  local minutes = math.floor(seconds / 60)
  local secs = seconds % 60
  return ("%d:%02d"):format(minutes, secs)
end

--- Format a raw transcript into an array of lines: one sentence per line,
--- wrapped so no line exceeds max_width unless a single token already did.
function M.format_transcript(text, max_width)
  local lines = {}
  for _, sentence in ipairs(M.split_sentences(text)) do
    for _, line in ipairs(M.wrap_sentence(sentence, max_width)) do
      table.insert(lines, line)
    end
  end
  return lines
end

return M
