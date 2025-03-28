A neovim plugin to call [llm](https://llm.datasette.io/en/stable/) inline.

*Talk to ChatGPT, Claude, etc from neovim!*

*Instant code reviews!*

*AI Code completion, it's almost like Cursor but built with sticky tape and twine!*

Usage summary:
- Select some text, or nothing to send the whole buffer.
- Hit the shortcut key `<leader>l`, choose "Query".
- Plugin sends the selected text to `llm` cmd line.
- Plugin opens a vertical split and displays the output on the right.
- Continue the conversation in that buffer. Don't select any text this time.

# Install and setup

Make sure you have `llm` setup and working, with an OpenAI API key (or relevant key for your AI).

Add this to your init.lua (vim-plug, customise for your nvim package manager).
```
Plug('grahamking/calum.nvim')

require('calum').setup{}
```

Press `<leader>l`, select an option. Default model is OpenAI's 4o-mini.

# Customize

```
require('calum').setup{
  -- What to press to activate Calum
  key = '<leader>l',

  -- All the available models. Must match choices from `llm models` including aliases.
  -- First one in the list is selected on startup.
  models = {'gemini-2.5-pro-exp-03-25', 'anthropic/claude-3-7-sonnet-latest', 'chatgpt-4o-latest'},
}
```

Gemini and Claude require `llm` plugins and relevant AI keys:
- `llm install -U llm-gemini`
- `llm install -U llm-anthropic`

You can also customise the system prompts, command line, etc. Check the `defaults` object in source.

# Use: Chat

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

You can continue working whilst the AI answers. The new pane doesn't auto scroll (I found that dizzying). Feel free to scroll the pane to see it.

## Continuing the chat

Switch to the new pane and find the `user>` line at the very bottom. Type your next prompt directly there, as if this was an interactive chat. Do not highlight anything this time, and press the mapped key (e.g. `<Leader>l`). The answer will appear in the current pane underneath your question. You can continue like this as long as necessary.

## Use: Code reviews

Highlight a code snippet or nothing to review the whole file, press `<Leader>l`, select Review. Instant code review!

## Use: Fill-in-the-middle, aka completion

With nothing selected, press `<Leader>l` select Fill. The AI will figure out what should go on that line based on what comes before and after, and fill it in. Here's an example:

This code
```
struct User {
    first: String,
    last: String,
    age: usize,
}

impl User {
    pub fn full_name(&self) -> String {
        --> YOUR CURSOR IS HERE <--
    }
    pub fn age(&self) -> usize {
        self.age
    }
}
```

It will fill the function with: `format!("{} {}", self.first, self.last)`.

# Misc

- [llm](https://llm.datasette.io/en/stable/) supports many models via it's [extensive plugin selection](https://llm.datasette.io/en/stable/plugins/directory.html#remote-apis).

- Why is it called "calum"? It started as "call-llm" but that's too boring. And it's a "calm" way of using AI. You select the text to send, you view the results, all inline, in a very simple setup.

- Originally co-authored with Claude 3.5 and 3.7. Re-written with Gemini 2.5 Pro. What a wonderful time to be a programmer.

