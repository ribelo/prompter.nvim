local JsonType = require("prompter_nvim.google.tool").JsonType
local GeminiTool = require("prompter_nvim.google.tool").Tool
local curl = require("plenary.curl")

TOOLS = {}

local docs_rs_tool = GeminiTool:new("docs_rs_browser")
  :with_description([[
    This tool lets you search docs.rs, the Rust documentation site, directly from your editor.  
    Provide a search query as input to find crates and modules. 
    Requires an active internet connection to fetch documentation.
  ]])
  :with_parameters({
    type = JsonType.OBJECT,
    properties = {
      query = {
        type = JsonType.STRING,
        description = "search query",
      },
    },
    required = { "query" },
  })
  :with_handler(function(input, _cx)
    local url =
      string.format("https://docs.rs/releases/search?query=%s", input.query)
    local response = curl.get(url):sync()
    vim.print(vim.inspect({ response = response }))
    return { response = response }
  end)

TOOLS["docs_rs_browser"] = docs_rs_tool
