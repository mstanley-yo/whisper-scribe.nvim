local format = require("whisper-scribe.format")

describe("split_sentences", function()
  it("splits on period, exclamation, and question mark", function()
    local out = format.split_sentences("One. Two! Three?")
    assert.are.same({ "One.", "Two!", "Three?" }, out)
  end)

  it("treats runs of terminators as one boundary", function()
    local out = format.split_sentences("Really?! Are you sure... Yes.")
    assert.are.same({ "Really?!", "Are you sure...", "Yes." }, out)
  end)

  it("does not split mid-decimal", function()
    local out = format.split_sentences("Pi is 3.14 roughly. Next sentence.")
    assert.are.same({ "Pi is 3.14 roughly.", "Next sentence." }, out)
  end)

  it("handles a trailing sentence with no terminator", function()
    local out = format.split_sentences("First one. trailing fragment")
    assert.are.same({ "First one.", "trailing fragment" }, out)
  end)
end)

describe("wrap_sentence", function()
  it("passes a short sentence through unchanged", function()
    local out = format.wrap_sentence("This is short.", 72)
    assert.are.same({ "This is short." }, out)
  end)

  it("wraps a long sentence on commas", function()
    local sentence = "This is a fairly long clause, followed by another long clause, "
      .. "and then one more clause here, ending the sentence."
    local out = format.wrap_sentence(sentence, 72)
    assert.is_true(#out > 1)
    for _, line in ipairs(out) do
      assert.is_true(#line <= 72)
    end
  end)

  it("falls back to word-wrap when a comma-clause is still too long", function()
    local sentence = "thisisonereallylongwordthatkeepsgoing, but the rest is short, "
      .. "and here is a clause with plenty of words that will not fit on one single short line at all"
    local out = format.wrap_sentence(sentence, 20)
    for _, line in ipairs(out) do
      -- every line fits, except one that is a single unsplittable token
      local words = format.split_words(line)
      assert.is_true(#line <= 20 or #words == 1)
    end
  end)

  it("falls back to word-wrap when there are no commas at all", function()
    local sentence = "word " .. string.rep("longish ", 20):gsub("%s+$", "")
    local out = format.wrap_sentence(sentence, 30)
    assert.is_true(#out > 1)
    for _, line in ipairs(out) do
      assert.is_true(#line <= 30)
    end
  end)
end)

describe("format_transcript", function()
  it("produces one line per short sentence", function()
    local out = format.format_transcript("First sentence. Second sentence. Third one.", 72)
    assert.are.same({ "First sentence.", "Second sentence.", "Third one." }, out)
  end)

  it("never exceeds max_width unless a single token already did", function()
    local text = "Short one. "
      .. "A quite long sentence with several clauses, each one adding more length, "
      .. "and finishing off with a final clause to push it over the limit. "
      .. "Another long sentence without any commas at all that just keeps going and going and going on."
    local out = format.format_transcript(text, 72)
    for _, line in ipairs(out) do
      local words = format.split_words(line)
      assert.is_true(#line <= 72 or #words == 1)
    end
  end)
end)
