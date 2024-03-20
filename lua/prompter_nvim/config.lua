local M = {}

M.openai_api_key = vim.fn.systemlist("echo $OPENAI_API_KEY")[1]
M.anthropic_api_key = vim.fn.systemlist("echo $ANTHROPIC_API_KEY")[1]
M.context_size = 32
M.temperature = 0.1
M.completion_model = "text-davinci-003"
M.edit_model = "text-davinci-edit-001"
M.max_tokens = 2048
M.sign_text = ""
M.sign_hl = "SignColumn"
M.global_prompts_path = vim.fn.stdpath("data") .. "/prompts"
M.local_prompts_path = "./.prompts"

return M
