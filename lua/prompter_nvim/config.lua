local M = {}

CONFIG = {
  openai_api_key = vim.fn.systemlist("echo $OPENAI_API_KEY")[1],
  anthropic_api_key = vim.fn.systemlist("echo $ANTHROPIC_API_KEY")[1],
  groq_api_key = vim.fn.systemlist("echo $GROQ_API_KEY")[1],

  gemini_api_key = vim.fn.systemlist("echo $GEMINI_API_KEY")[1],
  gemini_api_version = "v1",
  gemini_api_endpoint = "",
  gemini_location = "",
  gemini_project_id = "",

  global_prompts_path = vim.fn.stdpath("data") .. "/prompts",
  local_prompts_path = "./.prompts",
}

M.get = function()
  return CONFIG
end

M.set = function(opts)
  CONFIG = vim.tbl_extend("force", CONFIG, opts)
end

return M
