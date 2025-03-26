# 🧠 Neovim Ollama AI Plugin

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE) 

**Engineering Design Project** · ASTE 3440 · Spring 2025  
*A minimal Neovim plugin for interacting with local AI models via Ollama.  
Developed with assistance from [Deepseek AI](https://deepseek.com).*

---

▶️ **Demo Video**: [YouTube Demonstration](https://youtu.be/1tn0CiQXSiE)

---

## 📖 Table of Contents
- [Features](#-features)
- [Prerequisites](#-prerequisites)
- [Installation](#-installation)
- [Configuration](#-configuration)

---

## ✨ Features
- **Local AI Integration**: Connect to Ollama-hosted models (Llama3, Deepseek, etc.)
- **Customizable Workflows**: Predefine prompts for code review, documentation, etc.
- **Buffer-Based Interaction**: Chat with AI directly within Neovim
- **Zero External Dependencies**: Pure Lua implementation

---

## ⚙️ Prerequisites
- [Ollama](https://ollama.ai) running locally (`ollama serve`)
- Neovim ≥ 0.9
- Configured Ollama API endpoint (default: `http://localhost:11434`)

---

## 📦 Installation

Using [Lazy.nvim](https://github.com/folke/lazy.nvim):

## 🔧 Configuration

Below are all available configuration options with their default values:

```lua
require('ai-chat').setup {
  -- Window styling
  window = {
    width = 60,       -- Default width in columns
    height = 20,      -- Default height in lines
    border = "rounded" -- Border style (none, single, double, rounded, shadow)
  },
  
  -- Ollama connection settings
  ollama = {
    model = "deepseek-r1:8b",       -- Default model to use
    base_url = "http://127.0.0.1:11434" -- Ollama server URL
  },
  
  -- Keybindings
  keys = {
    open = "<leader>ai" -- Keybind to toggle chat window
  },
}
