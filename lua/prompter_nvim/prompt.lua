local pf = require("plenary.filetype")

---@class Chunk
---@field content string
---@field cwd string
---@field file_path string
---@field tag string?
---@field description string?

---@class Prompt
---@field chunks Chunk[]
local Prompt = {}
Prompt.__index = Prompt

-- Function to find the minimum indentation of a string
---@param str string
local function get_min_indent(str)
  ---@type string[]
  local lines = {}
  for line in str:gmatch("[^\n]+") do
    table.insert(lines, line)
  end

  local min_indent = math.huge
  for _, line in ipairs(lines) do
    local indent = line:match("^%s*")
    min_indent = math.min(min_indent, #indent)
  end

  return min_indent
end

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

  ---@type {string: {cwd: string, file_type: string, chunks: Chunk[]}}
  local grouped_chunks = {}

  -- Group chunks by file_path
  for _, chunk in ipairs(self.chunks) do
    if not grouped_chunks[chunk.file_path] then
      grouped_chunks[chunk.file_path] = {
        cwd = chunk.cwd,
        file_type = pf.detect_from_extension(chunk.file_path),
        chunks = {},
      }
    end
    table.insert(grouped_chunks[chunk.file_path].chunks, chunk)
  end

  table.insert(result, "<data>")

  -- Process grouped chunks
  ---@param file_path string
  for file_path, chunk_group in pairs(grouped_chunks) do
    table.insert(result, "  <document>")
    table.insert(result, "    <metadata>")
    table.insert(
      result,
      "      <working_directory>" .. chunk_group.cwd .. "</working_directory>"
    )
    table.insert(result, "      <file_path>" .. file_path .. "</file_path>")
    table.insert(
      result,
      "      <file_type>" .. chunk_group.file_type .. "</file_type>"
    )
    table.insert(result, "    </metadata>")
    table.insert(result, "    <content>")

    for _, block in ipairs(chunk_group.chunks) do
      if block.description and block.description ~= "" then
        table.insert(result, "      <description>")
        table.insert(result, "        " .. block.description)
        table.insert(result, "      </description>")
      end

      local tag_name = block.tag or "code_block"
      if block.content and block.content ~= "" then
        table.insert(result, "      <" .. tag_name .. ">")

        -- Find the minimum indentation of the content
        local min_indent = get_min_indent(block.content)

        -- Prepend each line of the content with " " and adjust indentation
        local content_lines = {}
        for line in block.content:gmatch("[^\n]+") do
          local adjusted_line = line:sub(min_indent + 1)
          table.insert(content_lines, "          " .. adjusted_line)
        end

        table.insert(result, table.concat(content_lines, "\n"))
        table.insert(result, "      </" .. tag_name .. ">")
      end
    end
    table.insert(result, "    </content>")

    table.insert(result, "  </document>")
  end

  table.insert(result, "</data>")
  return table.concat(result, "\n")
end

function Prompt:length()
  return #self.chunks
end

return Prompt
