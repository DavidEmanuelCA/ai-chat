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
  M.config = vim.tbl_deep_extend("force", default_config, user_config or {})
  M.setup_keybindings()
end

-- Set up keybindings
function M.setup_keybindings()
  vim.api.nvim_set_keymap(
    "n",
    M.config.keys.open,
    ":lua require('ollama-chat').open_chat_window()<CR>",
    { noremap = true, silent = true }
  )
end

-- Create a floating window
function M.create_floating_window()
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = M.config.window.width,
    height = M.config.window.height,
    row = M.config.window.row,
    col = M.config.window.col,
    style = "minimal",
    border = M.config.window.border,
  })

  -- Set keymaps for the window
  vim.api.nvim_buf_set_keymap(buf, "n", "q", ":q<CR>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", ":q<CR>", { noremap = true, silent = true })

  return buf, win
end

-- Ask Ollama a question
function M.ask_ollama(prompt)
  local cmd = string.format(
    "curl -s -X POST %s/api/generate -d '{\"model\": \"%s\", \"prompt\": \"%s\"}'",
    M.config.ollama.base_url,
    M.config.ollama.model,
    prompt
  )

  local response = vim.fn.system(cmd)

  -- Error handling for Ollama
  if vim.v.shell_error ~= 0 then
    return nil, "Failed to communicate with Ollama. Is it running?"
  end

  -- Parse the response (Ollama returns JSON)
  local ok, json = pcall(vim.fn.json_decode, response)
  if not ok then
    return nil, "Failed to parse Ollama response."
  end

  if json.error then
    return nil, json.error
  end

  return json.response, nil
end

-- Get dynamic prompt based on context
function M.get_dynamic_prompt()
  if not M.config.prompt.dynamic.enabled then
    return M.config.prompt.default
  end

  local context = M.config.prompt.dynamic.context

  if context == "file" then
    -- Use the current file as context
    local file_path = vim.fn.expand("%:p")
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
  local buf, win = M.create_floating_window()

  -- Display a default prompt or dynamic prompt
  local prompt = M.get_dynamic_prompt()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Type your question and press <Enter> to send.", "", prompt })

  -- Set up a prompt handler
  vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", ":lua require('ollama-chat').send_prompt()<CR>", { noremap = true, silent = true })
end

-- Send the current buffer content as a prompt to Ollama
function M.send_prompt()
  local buf = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local prompt = table.concat(lines, "\n")

  -- Ask Ollama and display the response
  local response, err = M.ask_ollama(prompt)
  if err then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Error: " .. err })
    return
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(response, "\n"))
end

return M
