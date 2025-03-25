local M = {}

-- Default configuration
local default_config = {
	window = {
		width = 60,
		height = 20,
		border = "rounded",
	},
	ollama = {
		model = "deepseek-r1:8b",
		base_url = "http://127.0.0.1:11434",
	},
	keys = {
		open = "<leader>oa",
	},
	prompt = {
		default = "How can I help with your code?",
		dynamic = {
			enabled = true,
			context = "file",
		},
	},
}

function M.setup(user_config)
	user_config = user_config or {}
	M.config = vim.tbl_deep_extend("force", default_config, user_config)
	M.setup_keybindings()
end

function M.setup_keybindings()
	vim.api.nvim_set_keymap(
		"n",
		M.config.keys.open,
		":lua require('ai-chat').open_chat_window()<CR>",
		{ noremap = true, silent = true }
	)
end

function M.create_floating_window()
	local buf = vim.api.nvim_create_buf(false, true)
	local width = math.min(M.config.window.width, math.floor(vim.o.columns * 0.4))
	local height = math.min(M.config.window.height, vim.o.lines - 4)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = vim.o.columns - width - 2,
		style = "minimal",
		border = M.config.window.border,
		noautocmd = true,
	})

	vim.api.nvim_win_set_option(win, "winhl", "NormalFloat:Normal")
	vim.api.nvim_buf_set_keymap(buf, "n", "q", ":q<CR>", { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", ":q<CR>", { noremap = true, silent = true })

	return buf, win
end

function M.ask_ollama(prompt)
	-- Use a temporary file to avoid JSON escaping issues
	local tmpfile = os.tmpname()
	local f = io.open(tmpfile, "w")
	f:write(
		string.format(
			'{"model": "%s", "prompt": "%s", "stream": false}',
			M.config.ollama.model,
			prompt:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n")
		)
	)
	f:close()

	local cmd = string.format(
		'curl -s -X POST %s/api/generate -d @%s -H "Content-Type: application/json"',
		M.config.ollama.base_url,
		tmpfile
	)

	local response = vim.fn.system(cmd)
	os.remove(tmpfile)

	if vim.v.shell_error ~= 0 then
		return nil, "Ollama request failed: " .. (response or "no response")
	end

	-- Handle streaming JSON responses
	local full_response = ""
	local error_message = nil

	-- Parse each JSON object in the response
	for line in response:gmatch("[^\r\n]+") do
		local ok, json = pcall(vim.fn.json_decode, line)
		if ok then
			if json.error then
				error_message = json.error
			end
			if json.response then
				full_response = full_response .. json.response
			end
		else
			-- Log invalid JSON line but continue processing
			vim.notify("Failed to parse JSON line: " .. line, vim.log.levels.WARN)
		end
	end

	if error_message then
		return nil, error_message
	end

	return full_response ~= "" and full_response or "No response received", nil
end

function M.open_chat_window()
	local buf, win = M.create_floating_window()

	-- Set initial content
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
		"=== AI Chat ===",
		"----------------------------------------",
		"",
		"Type your message and press <Enter> to send:",
		"",
	})

	-- Start in insert mode
	vim.api.nvim_win_set_cursor(win, { 5, 0 })
	vim.cmd("startinsert")

	-- Set send prompt mapping
	vim.api.nvim_buf_set_keymap(buf, "i", "<CR>", "<Cmd>lua require('ai-chat').send_prompt()<CR>", { noremap = true })
end

function M.send_prompt()
	local buf = vim.api.nvim_get_current_buf()
	local win = vim.api.nvim_get_current_win()

	-- Get user input
	local input_lines = vim.api.nvim_buf_get_lines(buf, 4, -1, false)
	local prompt = table.concat(input_lines, " "):gsub("%s+", " "):gsub("^%s*", ""):gsub("%s*$", "")

	if #prompt == 0 then
		vim.api.nvim_echo({ { "Error: Empty prompt", "ErrorMsg" } }, true, {})
		return
	end

	-- Add user message
	vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "You: " .. prompt, "" })

	-- Clear input
	vim.api.nvim_buf_set_lines(buf, 4, -1, false, { "" })

	-- Get and display response
	local response, err = M.ask_ollama(prompt)
	if err then
		vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "Error: " .. err, "" })
	else
		-- Split response into lines and format
		local response_lines = {}
		for line in vim.split(response, "\n") do
			if #response_lines == 0 then
				table.insert(response_lines, "AI: " .. line)
			else
				table.insert(response_lines, "    " .. line)
			end
		end

		-- Add separator and empty lines
		table.insert(response_lines, "")
		table.insert(response_lines, "----------------------------------------")
		table.insert(response_lines, "")
		table.insert(response_lines, "")

		vim.api.nvim_buf_set_lines(buf, -1, -1, false, response_lines)
	end

	-- Return to insert mode
	vim.api.nvim_win_set_cursor(win, { 5, 0 })
	vim.cmd("startinsert")
end

return M
