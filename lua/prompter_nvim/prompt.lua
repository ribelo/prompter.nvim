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

local function escape_xml(text)
  return text
    :gsub("&", "&amp;")
    :gsub("<", "&lt;")
    :gsub(">", "&gt;")
    :gsub("'", "&apos;")
    :gsub('"', "&quot;")
end

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
        cwd = chunk.cwd,
        filetype = pf.detect_from_extension(chunk.filepath),
        chunks = {},
      }
    end
    table.insert(grouped_chunks[chunk.filepath].chunks, chunk)
  end

  -- Process grouped chunks
  for filepath, chunk_group in pairs(grouped_chunks) do
    local doc_tag = "<doc>"
    table.insert(result, doc_tag)
    local cwd_tag = "  <cwd>" .. chunk_group.cwd .. "</cwd>"
    table.insert(result, cwd_tag)
    local filepath_tag = "  <filepath>" .. filepath .. "</filepath>"
    table.insert(result, filepath_tag)
    local filetype_tag = "  <filetype>" .. chunk_group.filetype .. "</filetype>"
    table.insert(result, filetype_tag)

    table.insert(result, "  <contents>")
    for _, chunk in ipairs(chunk_group.chunks) do
      local tag_name = chunk.tag or "content"
      if chunk.content and chunk.content ~= "" then
        table.insert(result, "    <" .. tag_name .. ">")
        local escaped_content = escape_xml(chunk.content)
        table.insert(result, escaped_content)
        table.insert(result, "    </" .. tag_name .. ">")
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

return Prompt
