local pf = require("plenary.filetype")

---@class Chunk
---@field content string
---@field cwd string
---@field filepath string
---@field tag string?

---@class Prompt
---@field chunks Chunk[]
local Prompt = {}
Prompt.__index = Prompt

function Prompt.new()
  local self = setmetatable({}, Prompt)
  self.chunks = {}
  return self
end

---@param chunk Chunk
function Prompt:push(chunk)
  table.insert(self.chunks, chunk)
end

function Prompt:pop()
  return table.remove(self.chunks)
end

function Prompt:peek()
  return self.chunks[#self.chunks]
end

function Prompt:is_empty()
  return #self.chunks == 0
end

function Prompt:clear()
  self.chunks = {}
end

function Prompt:get_chunks()
  return self.chunks
end

function Prompt:set_chunks(chunks)
  self.chunks = chunks
end

function Prompt:join()
  local result = {}

  if #self.chunks == 0 then
    return ""
  end

  local grouped_chunks = {}

  -- Group chunks by filepath
  for _, chunk in ipairs(self.chunks) do
    if not grouped_chunks[chunk.filepath] then
      grouped_chunks[chunk.filepath] = {
        tag_name = chunk.tag or "content",
        cwd = chunk.cwd,
        filetype = pf.detect_from_extension(chunk.filepath),
        contents = {},
      }
    end
    table.insert(grouped_chunks[chunk.filepath].contents, chunk.content)
  end

  -- Process grouped chunks
  for filepath, chunk_data in pairs(grouped_chunks) do
    local doc_tag = "<doc>"
    table.insert(result, doc_tag)
    local cwd_tag = "  <cwd>" .. chunk_data.cwd .. "</cwd>"
    table.insert(result, cwd_tag)
    local filepath_tag = "  <filepath>" .. filepath .. "</filepath>"
    table.insert(result, filepath_tag)
    local filetype_tag = "  <filetype>" .. chunk_data.filetype .. "</filetype>"
    table.insert(result, filetype_tag)

    table.insert(result, "  <contents>")
    for _, content in ipairs(chunk_data.contents) do
      if content and content ~= "" then
        table.insert(result, "    <" .. chunk_data.tag_name .. ">")
        table.insert(result, self:escape_xml(content))
        table.insert(result, "    </" .. chunk_data.tag_name .. ">")
      end
    end
    table.insert(result, "  </contents>")

    table.insert(result, "</doc>")
  end

  return table.concat(result, "\n")
end

function Prompt:length()
  return #self.chunks
end

function Prompt:escape_xml(text)
  return text
    :gsub("&", "&amp;")
    :gsub("<", "&lt;")
    :gsub(">", "&gt;")
    :gsub("'", "&apos;")
    :gsub('"', "&quot;")
end

return Prompt
