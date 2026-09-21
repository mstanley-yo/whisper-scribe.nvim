local format = require("whisper-scribe.format")

describe("format_duration", function()
  it("formats zero seconds", function()
    assert.are.equal("0:00", format.format_duration(0))
  end)

  it("formats single-digit seconds with a leading zero", function()
    assert.are.equal("0:07", format.format_duration(7))
  end)

  it("formats minutes and seconds", function()
    assert.are.equal("1:03", format.format_duration(63))
  end)

  it("floors fractional seconds", function()
    assert.are.equal("0:04", format.format_duration(4.9))
  end)
end)
