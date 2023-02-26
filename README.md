# prompter.nvim

Do we need another one for the collection of 2137 nvim plugins using GPT-3? You
may not need it, but I do. did. Most extensions allow you to write ad hoc
prompts or just play around like with ChatGPT, but it's far from how I would
like to use it. The greatest power of GPT-3 is the carefully crafted prompts
for many tasks, ranging from language translation, refactoring or eli5.

This plugin allows you to create prompts in `JSON`, with all the necessary
variables like `temperature`, `endpoint`, or `model`, which allows for
different settings for different prompts. The prompts themselves are equipped
with ridiculously simple `{{mustache}}`-like templates, which allow for even
more intricate prompt preparation. Currently, basic things like
`{{selection}}`, `{{filepath}}`, `{{filename}}`, `{{filetype}}` are being
passed. You can also define your own parameters through
`config.template_params`. You can put your dog's name in the template if you
need to. This allows for dynamic prompt creation based on the programming
language you are currently writing.

## Installation

Install with what you are using there. It doesn't really need an explanation.
All you need to do is run `require("prompter_nvim").setup(opts?)`.

## Configuration

### Default config

```lua
-- prompter_nvim.config
local M = {}

M.openai_api_key = vim.fn.systemlist("echo $OPENAI_API_KEY")[1]
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
```

## Usage

The commands `:PrompterContinue`, `:PrompterReplace`, `:PrompterEdit`, and `:PrompterBrowser` are registered.

### PrompterContinue

Put the response from the API either in the current line, or in the case of
selection from the next line after the end of the selection. If there is no
selection, use text from the current line to the current minus
`config.context_size`. API often returns blank lines at the beginning or end of
the response, so it is trimmed. The text is prepended with the `cmd` arguments.

`{{There will be a video sometime}}`

### PrompterReplace

Everything as above, except replacing the selection with the answer from the API.

`{{There will be a video sometime}}`

### PrompterEdit

Use the edits endpoint. The `cmd` arguments are used as instructions and the
selection as input. The rest is as above.

`{{There will be a video sometime}}`

### PrompterBrowser

The whole thing is based mostly on `Telescope`, which allows you to browse saved
prompts. In the `previewer` you can see the formatted template right away. Sending
to the API is done through `select_default`, usually `<CR>.` After receiving a
response from the API, the `previewer` will be replaced with the response. You
can copy it using `<C-y>` or replace the selected text in the buffer with
`<C-p>`.

## Prompts

```json
{
  "endpoint": "completions",
  "model": "text-davinci-003",
  "name": "example prompt",
  "trim_result": true,
  "prompt": "ELI5. Explain the {{filetype}} code below as if you were talking to a five-year-old:\n\n{{selection}}"
}
```

JSON must have a `prompt` for the `completions` endpoint or `instruction` for
`edits`. The rest is optional. `trim_result` allows you to trim empty lines at
the beginning and end of the response. Currently available variables for the
prompt are:

- `{{filepath}}`
- `{{filename}}`
- `{{filetype}}`

You can put a certain amount of variables into `opts.template_params`. If the
parameter is a function, the result of that function will be used.

## License

Unlicensed
