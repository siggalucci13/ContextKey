# 🔑 ContextKey

> **Because Context is Key!**

A macOS menu bar app that brings AI to your fingertips. Select any text, press a hotkey, and get instant AI-powered answers without leaving your workflow.

**Works with Ollama (local) and any API** - OpenAI, Anthropic, Google Gemini, xAI, or your own custom endpoint.

---

## ✨ What It Does

ContextKey lets you:
- 🚀 **Select text anywhere** and instantly query AI about it
- 💬 **Keep conversation history** with full context preservation
- 🤖 **Use any LLM**: Ollama (local), OpenAI, Anthropic, xAI, Google Gemini, or any custom API
- 🖼️ **Attach images and files** for analysis (vision models)
- ⚡ **Two modes**: Full-featured main window + quick popup window
- 🎯 **Control context**: Choose what to include in each query

---

## 🎬 Demo

[Video demo coming soon]

---

## 🚀 Quick Start

1. **Download** the app from [Releases](https://github.com/yourusername/ContextKey/releases)
2. **Move** to Applications folder and launch
3. **Grant permissions** when prompted (File Access, Accessibility)
4. **Select a folder** to store your conversations and settings
5. **Add an LLM configuration** (see below)

---

## ⚙️ Setup Guide

### Option 1: Ollama (Local, Free)

Run AI models locally on your Mac:

```bash
# Install Ollama
brew install ollama

# Start Ollama
ollama serve

# Pull a model (in a new terminal)
ollama pull llama3.2
```

**In ContextKey:**
1. Click ⚙️ Settings → Add Configuration
2. Select **"Ollama"** (not Custom)
3. Endpoint: `http://localhost:11434`
4. Click **"Fetch Models"** to see installed models
5. Select your model → Add Configuration
6. Click **"Set Active"** to use it

### Option 2: Any API (OpenAI, Anthropic, Gemini, etc.)

All cloud APIs use the **"Custom"** option. Here are examples:

#### OpenAI (GPT-4, ChatGPT, DALL-E)

1. Click ⚙️ Settings → Add Configuration
2. Select **"Custom"**
3. Fill in:
   - **Name**: `GPT-4`
   - **API Key**: Get from [platform.openai.com](https://platform.openai.com)
   - **Endpoint**: `https://api.openai.com/v1/chat/completions`
   - **HTTP Method**: `POST`
   - **Headers**: `{"Content-Type": "application/json"}`
   - **Request Template**:
     ```json
     {
       "model": "gpt-4",
       "messages": [
         {
           "role": "user",
           "content": "{{input}}"
         }
       ]
     }
     ```
   - **Response Path**: `choices[0].message.content`
4. Click Add Configuration → Set Active

#### Anthropic (Claude)

1. Click ⚙️ Settings → Add Configuration
2. Select **"Custom"**
3. Fill in:
   - **Name**: `Claude`
   - **API Key**: Get from [console.anthropic.com](https://console.anthropic.com)
   - **Endpoint**: `https://api.anthropic.com/v1/messages`
   - **HTTP Method**: `POST`
   - **Headers**: `{"Content-Type": "application/json", "anthropic-version": "2023-06-01"}`
   - **Request Template**:
     ```json
     {
       "model": "claude-3-5-sonnet-20241022",
       "max_tokens": 1024,
       "messages": [
         {
           "role": "user",
           "content": "{{input}}"
         }
       ]
     }
     ```
   - **Response Path**: `content[0].text`
4. Click Add Configuration → Set Active

#### Google Gemini

1. Click ⚙️ Settings → Add Configuration
2. Select **"Custom"**
3. Fill in:
   - **Name**: `Gemini Pro`
   - **API Key**: Get from [ai.google.dev](https://ai.google.dev)
   - **Endpoint**: `https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent`
   - **HTTP Method**: `POST`
   - **Headers**: `{"Content-Type": "application/json"}`
   - **Request Template**:
     ```json
     {
       "contents": [
         {
           "parts": [
             {
               "text": "{{input}}"
             }
           ]
         }
       ]
     }
     ```
   - **Response Path**: `candidates[0].content.parts[0].text`
4. Click Add Configuration → Set Active

**Template Guide:**
- Use `{{input}}` where you want the user's message + context inserted
- API key is automatically added to headers for you
- Response Path uses dot notation: `field.nested.array[0].value`

---

## 📖 How to Use

### Quick Window (Recommended)

1. **Select text** in any app
2. Press **`Cmd+Shift+K`**
3. Ask your question
4. Get instant answers!

Or press **`Cmd+Option+K`** to open without context.

### Main Window

1. Open the app from menu bar
2. (Optional) Add initial context or attach files
3. Type your question and press Enter
4. Continue the conversation or browse history in the sidebar

### Context Options

Before sending a message, choose what to include:
- ✅ **Initial Context + Conversation**: Full context with history (default)
- 📄 **Initial Context Only**: Just the starting context
- ❌ **Neither**: Only your current question

---

## 🔒 Privacy

- All data stored **locally** on your Mac
- API keys saved in local files (you control backups)
- Zero telemetry or tracking
- Code is open source—audit it yourself!

---

## 🤝 Contributing

Contributions welcome! Fork the repo, make your changes, and open a Pull Request.

---

## 📜 License

MIT License - see [LICENSE](LICENSE) for details.

---

<p align="center">
  <i>Context really is key. 🔑</i>
</p>
