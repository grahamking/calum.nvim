A neovim plugin to call [llm](https://llm.datasette.io/en/stable/) inline, or really any command line AI chat you want.

- Select some text.
- Hit the shortcut key `<leader>l`.
- Plugin sends the selected text to `llm`.
- Plugin opens a vertical split and displays the output on the right.
- Continue the conversation in that buffer. Don't select any text this time.

That's it!

# Install and setup

There are three important steps.

1. First make sure you have `llm` setup and working, with an OpenAI API key.

2. Add this to your init.lua (vim-plug, customise for your nvim package manager).
```
Plug('grahamking/calum.nvim')
```

3. Add a key mapping or two

In your `.config/nvim/init.lua` (or init.vim equivalent) add these lines:

```
local gpt_small_cmd = 'llm -m gpt-4o-mini -s \'Be brief\' -o max_tokens 4096'
vim.api.nvim_set_keymap('v', '<leader>l', string.format(':Calum %s<CR>', gpt_small_cmd), { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>l', string.format(':Calum %s<CR>', gpt_small_cmd), { noremap = true, silent = true })

local gpt_big_cmd = 'llm -m gpt-4o -o max_tokens 4096'
vim.api.nvim_set_keymap('v', '<leader>p', string.format(':Calum %s<CR>', gpt_big_cmd), { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>p', string.format(':Calum %s<CR>', gpt_big_cmd), { noremap = true, silent = true })
```

This maps `<leader>l` to a brief gpt-4o-mini, and `<leader>p` to 4o without the system prompt. Customise at will! For example you may wish to use an internal model at your work, to avoid sending proprietary info outside your org.

Notice how you can completely replace the command line. Calum will call it like this:
```
bash -c 'cat <file-containing-your-prompt> | <your-command>'
```
The output of that goes into the new buffer. Your command needs to accept it's prompt on stdin.

# Misc

Why is it called "calum"? It started as "call-llm" but that's too boring. And it's a "calm" way of using AI. You select the text to send, you view the results, all inline, in a very simple setup.

