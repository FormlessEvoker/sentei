-- Pandoc's gfm writer emits indented code blocks when a block has no
-- language. Sentei's output contract requires fenced blocks, so emit those
-- as raw gfm, with a fence longer than any backtick run inside the code.
function CodeBlock(block)
  if #block.classes > 0 then
    return nil
  end

  local longest = 0
  for run in block.text:gmatch("`+") do
    longest = math.max(longest, #run)
  end
  local fence = string.rep("`", math.max(3, longest + 1))

  local body = block.text == "" and "" or block.text .. "\n"
  return pandoc.RawBlock("gfm", fence .. "\n" .. body .. fence)
end
