A neovim plugin to call [llm](https://llm.datasette.io/en/stable/) inline.

- Select some text
- Hit the shortcut key. I use `<leader>l`
- Plugin sends the selected text to `llm`
- Plugin opens a vertical split and displays the output on the right

That's it!

# Install and setup

First make sure you have `llm` setup and working, with an OpenAI API key.

## vim-plug

Add this to your init.lua
```
Plug('grahamking/calum.nvim')
```

(or similar with your installer of choice)

## Shortcut

Map the function to a key combination.

```
vim.api.nvim_set_keymap('v', '<leader>l', ':Calum gpt-4o-mini<CR>', { noremap = true, silent = true })
```

The parameter is anything from `llm models`, feel free to change it. Map several keys, use all the models!

# Use

Highlight some text (`<shift>-V`) then `<leader>l`

# Misc

I limit the models output tokens (`max_tokens`) to 1024, which is three screens of text on my setup. More than enough.

Why is it called "calum"? It started as "call-llm" but that's too boring. And it's a "calm" way of using AI. You select the text to send, you view the results, all inline, in a very simple setup.

