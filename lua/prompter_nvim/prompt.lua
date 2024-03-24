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
  for i, chunk in ipairs(self.chunks) do
    ---@type string
    local tag
    if chunk.tag and chunk.tag ~= "" then
      tag = "<" .. chunk.tag .. ">"
    else
      tag = '<doc index="' .. i .. '">'
    end
    table.insert(result, tag)

    if chunk.cwd and chunk.cwd ~= "" then
      table.insert(result, "  <cwd>" .. self:escape_xml(chunk.cwd) .. "</cwd>")
    end

    if chunk.filepath and chunk.filepath ~= "" then
      table.insert(
        result,
        "  <filepath>" .. self:escape_xml(chunk.filepath) .. "</filepath>"
      )
      local filetype = pf.detect_from_extension(chunk.filepath)
      if filetype and filetype ~= "" then
        table.insert(
          result,
          "  <filetype>" .. self:escape_xml(filetype) .. "</filetype>"
        )
      end
    end

    if chunk.content and chunk.content ~= "" then
      table.insert(
        result,
        "  <content>" .. self:escape_xml(chunk.content) .. "</content>"
      )
    end

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
