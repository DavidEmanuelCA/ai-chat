local M = {}

-- Default configuration
local default_config = {
	-- Floating window settings
	window = {
		width = 200,
		height = 200,
		row = 1,
		col = 1,
		border = "rounded", -- Options: "none", "single", "double", "rounded", "shadow"
	},
	-- Ollama settings
	ollama = {
		model = "deepseek-r1:8b", -- Default model
		base_url = "http://127.0.0.1:11434", -- Ollama API URL
	},
	-- Keybindings
	keys = {
		open = "<leader>oa", -- Keybinding to open the chat window
	},
	-- Prompt settings
	prompt = {
		default = "Explain this codebase.", -- Default prompt
		dynamic = {
			enabled = true, -- Enable dynamic prompts
			context = "file", -- Options: "file", "project", "none"
		},
	},
}

-- Merge user configuration with defaults
function M.setup(user_config)
	-- Ensure all configuration sections exist and are tables
	user_config = user_config or {}
	user_config.window = user_config.window or {}
	user_config.ollama = user_config.ollama or {}
	user_config.keys = user_config.keys or {}
	user_config.prompt = user_config.prompt or {}
	user_config.prompt.dynamic = user_config.prompt.dynamic or {}

	-- Merge with defaults
	M.config = vim.tbl_deep_extend("force", default_config, user_config)

	-- Validate required fields
	M.config.ollama.model = M.config.ollama.model or "deepseek-r1:8b"
	M.config.ollama.base_url = M.config.ollama.base_url or "http://127.0.0.1:11434"

	M.setup_keybindings()
end

-- Set up keybindings
function M.setup_keybindings()
	vim.api.nvim_set_keymap(
		"n",
		M.config.keys.open,
		":lua require('ai-chat').open_chat_window()<CR>",
		{ noremap = true, silent = true }
	)

	-- Add mapping to close chat from insert mode
	vim.api.nvim_set_keymap("i", "<C-c>", "<Esc>:q<CR>", { noremap = true, silent = true })
end

function M.create_floating_window()
	local buf = vim.api.nvim_create_buf(false, true)
	local width = math.min(M.config.window.width, math.floor(vim.o.columns * 0.4)) -- Max 40% of screen width
	local height = math.min(M.config.window.height, vim.o.lines - 4) -- Leave some margin

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2), -- Center vertically
		col = vim.o.columns - width - 2, -- Right side with small margin
		style = "minimal",
		border = M.config.window.border,
		noautocmd = true,
	})

	-- Window styling
	vim.api.nvim_win_set_option(win, "winhl", "NormalFloat:Normal")
	vim.api.nvim_win_set_option(win, "winblend", 0)

	-- Initial content with clear separation
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
		"=== AI Chat ===",
		"",
		"Type your message below and press <Enter> to send:",
		"----------------------------------------",
		"",
	})

	-- Start in insert mode at the end
	vim.api.nvim_win_set_cursor(win, { 6, 0 })
	vim.cmd("startinsert!")

	-- Keymaps
	vim.api.nvim_buf_set_keymap(buf, "i", "<CR>", "<Cmd>lua require('ai-chat').send_prompt()<CR>", { noremap = true })
	vim.api.nvim_buf_set_keymap(buf, "n", "q", ":q<CR>", { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", ":q<CR>", { noremap = true, silent = true })

	return buf, win
end

-- Ask Ollama a question
function M.ask_ollama(prompt)
	-- Input validation
	if type(prompt) ~= "string" or #prompt == 0 then
		return nil, "Prompt must be a non-empty string"
	end

	local cmd = string.format(
		[[curl -s -X POST %s/api/generate -d '{"model": "%s", "prompt": "%s"}']],
		M.config.ollama.base_url,
		M.config.ollama.model,
		prompt:gsub('"', '\\"'):gsub("\n", "\\n")
	)

	local response = vim.fn.system(cmd)

	-- Check for curl errors
	if vim.v.shell_error ~= 0 then
		return nil, "Failed to connect to Ollama: " .. (response or "no response")
	end

	-- Safe JSON parsing
	local ok, json = pcall(vim.fn.json_decode, response)
	if not ok then
		return nil, "Invalid JSON response: " .. (response or "empty response")
	end

	-- Check for Ollama errors
	if type(json) ~= "table" then
		return nil, "Unexpected response format"
	end
	if json.error then
		return nil, json.error
	end

	return json.response or json.text or "No response text found", nil
end

-- Get dynamic prompt based on context
function M.get_dynamic_prompt()
	if not M.config.prompt.dynamic.enabled then
		return M.config.prompt.default
	end

	local context = M.config.prompt.dynamic.context

	if context == "file" then
		-- Use the current file as context
		local file_path = vim.fn.expand("%:p") -- Get the full path of the current file
		if file_path == "" then
			return "No file is currently open. Using default prompt."
		end

		-- Check if the file exists and is readable
		if vim.fn.filereadable(file_path) == 0 then
			return "Unable to read the current file. Using default prompt."
		end

		-- Read the file content
		local file_content = vim.fn.readfile(file_path)
		return string.format("Explain this file:\n%s", table.concat(file_content, "\n"))
	elseif context == "project" then
		-- Use the current project directory as context
		local project_root = vim.fn.getcwd()
		return string.format("Explain this project located at:\n%s", project_root)
	else
		-- Fallback to default prompt
		return M.config.prompt.default
	end
end

-- Open the chat window and interact with Ollama
function M.open_chat_window()
	if type(M.config) ~= "table" then
		vim.notify("ai-chat: Configuration not initialized", vim.log.levels.ERROR)
		return
	end
	local buf, win = M.create_floating_window()

	-- Display a default prompt or dynamic prompt
	local prompt = M.get_dynamic_prompt()
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Type your question and press <Enter> to send.", "", prompt })

	-- Set up a prompt handler
	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"<CR>",
		":lua require('ai-chat').send_prompt()<CR>",
		{ noremap = true, silent = true }
	)
end

-- Send the current buffer content as a prompt to Ollama
function M.send_prompt()
	local buf = vim.api.nvim_get_current_buf()
	local win = vim.api.nvim_get_current_win()

	-- Get only the user input (below the separator)
	local lines = vim.api.nvim_buf_get_lines(buf, 5, -1, false)
	local prompt = table.concat(lines, "\n")

	-- Clear the input area
	vim.api.nvim_buf_set_lines(buf, 5, -1, false, { "" })

	if #prompt:gsub("%s+", "") == 0 then
		vim.api.nvim_echo({ { "Error: Prompt cannot be empty", "ErrorMsg" } }, true, {})
		return
	end

	-- Add user message to chat history
	vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "You: " .. prompt, "" })

	-- Get response
	local response, err = M.ask_ollama(prompt)
	if err then
		vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "Error: " .. err, "" })
	else
		-- Split response into lines and add to buffer
		local response_lines = {}
		for line in response:gmatch("[^\n]+") do
			table.insert(response_lines, "AI: " .. line)
		end
		vim.api.nvim_buf_set_lines(buf, -1, -1, false, response_lines)
		vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "" })
	end

	-- Scroll to bottom and return to insert mode
	vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(buf), 0 })
	vim.cmd("startinsert!")
end
