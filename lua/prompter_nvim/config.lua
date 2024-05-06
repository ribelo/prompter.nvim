local M = {}

M.openai_api_key = vim.fn.systemlist("echo $OPENAI_API_KEY")[1]
M.anthropic_api_key = vim.fn.systemlist("echo $ANTHROPIC_API_KEY")[1]
M.groq_api_key = vim.fn.systemlist("echo $GROQ_API_KEY")[1]
M.global_prompts_path = vim.fn.stdpath("data") .. "/prompts"
M.local_prompts_path = "./.prompts"

return M
