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
			'{"model": "%s", "prompt": "%s"}',
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

	local ok, json = pcall(vim.fn.json_decode, response)
	if not ok then
		return nil, "Invalid JSON response: " .. (response or "empty response")
	end

	if json.error then
		return nil, json.error
	end

	return json.response or json.text or "No response text found", nil
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

	-- Get and validate user input
	local input_lines = vim.api.nvim_buf_get_lines(buf, 4, -1, false)
	local prompt = table.concat(input_lines, "\n"):gsub("^%s+", ""):gsub("%s+$", "")

	if #prompt == 0 then
		vim.api.nvim_echo({ { "Error: Empty prompt", "ErrorMsg" } }, true, {})
		return
	end

	-- Add user message to history
	vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "You: " .. prompt, "" })

	-- Clear input area
	vim.api.nvim_buf_set_lines(buf, 4, -1, false, { "" })

	-- Get response from Ollama
	local response, err = M.ask_ollama(prompt)
	if err then
		vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "Error: " .. err, "" })
	else
		-- Process the AI response safely
		local formatted_lines = { "AI: " } -- Start first line

		-- Split response into lines and handle empty responses
		if type(response) == "string" and #response > 0 then
			-- Split response into lines, trimming whitespace
			for line in vim.gsplit(response:gsub("\r", ""), "\n", { plain = true }) do
				if #line > 0 then
					if #formatted_lines == 1 then
						-- First line of response
						formatted_lines[1] = formatted_lines[1] .. line
					else
						-- Subsequent lines
						table.insert(formatted_lines, "    " .. line)
					end
				end
			end
		else
			table.insert(formatted_lines, "    [No response content]")
		end

		-- Add spacing and separator
		table.insert(formatted_lines, "")
		table.insert(formatted_lines, "----------------------------------------")
		table.insert(formatted_lines, "")
		table.insert(formatted_lines, "")

		-- Insert all lines safely
		vim.api.nvim_buf_set_lines(buf, -1, -1, false, formatted_lines)
	end

	-- Return to insert mode at proper position
	vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(buf), 0 })
	vim.cmd("startinsert")
end

return M
