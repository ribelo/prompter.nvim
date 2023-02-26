local prompter_nvim = require("prompter_nvim.core")
local config = require("prompter_nvim.config")

local M = {}

M.setup = function(opts)
	config = vim.tbl_extend("force", config, opts)
	vim.api.nvim_create_user_command("PrompterContinue", function(args)
		prompter_nvim.prompter_continue(args)
	end, {
		range = true,
		nargs = "*",
	})

	vim.api.nvim_create_user_command("PrompterReplace", function(args)
		prompter_nvim.prompter_replace(args)
	end, {
		range = true,
		nargs = "*",
	})

	vim.api.nvim_create_user_command("PrompterEdit", function(args)
		prompter_nvim.prompter_edit(args)
	end, {
		range = true,
		nargs = "+",
	})

	vim.api.nvim_create_user_command("PrompterBrowser", function(args)
		prompter_nvim.browser(args)
	end, {
		range = true,
		nargs = "*",
	})
end

return M
