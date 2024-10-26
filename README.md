A neovim plugin to call [llm](https://llm.datasette.io/en/stable/) inline, or really any command line you want.

*Talk to ChatGPT, Claude, etc from neovim!*

*Instant code reviews!*

Usage summary:
- Select some text.
- Hit the shortcut key `<leader>l`.
- Plugin sends the selected text to `llm` cmd line.
- Plugin opens a vertical split and displays the output on the right.
- Continue the conversation in that buffer. Don't select any text this time.

# Install and setup

There are three important steps.

1. First make sure you have `llm` setup and working, with an OpenAI API key (or relevant key for you AI).

2. Add this to your init.lua (vim-plug, customise for your nvim package manager).
```
Plug('grahamking/calum.nvim')
```

3. Add a key mapping or two

In your `.config/nvim/init.lua` (or init.vim equivalent) add these lines:

```
local gpt_small_cmd = 'llm -m gpt-4o-mini -s \'Be brief\' -o max_tokens 4096 -o temperature 0.2'
vim.api.nvim_set_keymap('v', '<leader>l', string.format(':Calum %s<CR>', gpt_small_cmd), { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>l', string.format(':Calum %s<CR>', gpt_small_cmd), { noremap = true, silent = true })

local gpt_big_cmd = 'llm -m gpt-4o -o max_tokens 4096 -o temperature 0.2'
vim.api.nvim_set_keymap('v', '<leader>p', string.format(':Calum %s<CR>', gpt_big_cmd), { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>p', string.format(':Calum %s<CR>', gpt_big_cmd), { noremap = true, silent = true })

local gpt_review_cmd = 'llm -m gpt-4o -o temperature 0.2 -s \'You are a code review tool. You will be given snippets of code which you will review. You first identify the language of the snippet, then you provide helpful precise comments and suggestions for improvements.	For each suggestion provide a recommended code change, if approriate. Be concise.\''
vim.api.nvim_set_keymap('v', '<leader>r', string.format(':Calum %s<CR>', gpt_review_cmd), { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>r', string.format(':Calum %s<CR>', gpt_review_cmd), { noremap = true, silent = true })
```

This maps `<leader>l` to a brief gpt-4o-mini, and `<leader>p` to 4o without the system prompt. Customise at will! For example you may wish to use an internal model at your work, to avoid sending proprietary info outside your org.

# Use

This section assumes you're using the key mappings above.

Whatever you select is the prompt. I typically use this plugin by writing a question above the code, highlighting my question and the code, and pressing `<Leader>l`. In this example I would highlight the two lines ("Implement .." and "struct .."):
 ```
<some code here>

Implement serde Deserialize for this struct. Use the existing TryInto impl to convert it from a String.
struct MyNewType(String)

<more other code here>
```

I then copy-paste what I need from the new pane, delete my prompt from this pane, and continue coding.

I also often put the prompt by itself right there:
```
<some code here>

In Rust write a struct called MyErr which implements Error.

<more other code here>
```

Here I would highlight that single line ("In Rust .."), and most likely replace it with the interesting parts from the new pane that opens.

The "Thinking..." box will close once the full response has been copied to the new pane, but you can continue working whilst it hovers. The new pane doesn't auto scroll (I found that dizzying). If the box is still there but nothing is changing on the output pane it means the content is appearing below the fold. Feel free to scroll the pane to see it.

## Continuing the chat

Switch to the new pane and find the `user>` line at the very bottom. Type your next prompt directly there, as if this was an interactive chat. Do not highlight anything this time, and press the mapped key (e.g. `<Leader>l`). The answer will appear in the current pane underneath your question. You can continue like this as long as necessary.

## Code reviews

Highligh a code snippet or the whole file, press `<Leader>r`. Instant code review!

# Misc

- I am using ChatGPT in my examples but you can of course use any model you want. In particular [llm](https://llm.datasette.io/en/stable/) supports Claude and Gemini via it's [extensive plugin selection](https://llm.datasette.io/en/stable/plugins/directory.html#remote-apis).

- You can completely replace the command line. Calum will call it like this:

```
bash -c 'cat <file-containing-your-prompt> | <your-command>'
```
The output of that goes into the new buffer. Your command needs to accept it's prompt on stdin. This should work very well with [chatgpt-cli](https://github.com/kardolus/chatgpt-cli) for example (although I haven't tried it yet).

- Why is it called "calum"? It started as "call-llm" but that's too boring. And it's a "calm" way of using AI. You select the text to send, you view the results, all inline, in a very simple setup.

