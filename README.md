# pacer.nvim

## TODO

2. Smart pausing - pause longer for paragraphs, end of sentences, etc. Love it.
5. Speed control while reading - use <C-,> and <C-.> to decrease and increase reading speed without needing to update the config/while the pacer is active
6. Reading progress - show a progress bar or percentage of the text read so far
7. Read from url - provide a url and read using w3m. Can this be done within Neovim?
8. Navigation while pacer is active - e.g. follow cursor/start from cursor if cursor is manually moved. E.g. I want to go to the next function/paragraph/etc. Also maybe skip back/forward a paragraph?
9. Context highlighting - subtle highlight of context to emphasize it, e.g. function signature and return statement of the current function, regardless of where in the function the pacer currently is
  - Multiple levels of context highlighting? E.g. to provide different levels of subtlety in highlighting for different levels of nesting.
  - Could just keep it simple and subtle highlight all contextually relevant lines

## Intro

A fast-paced reading plugin for Neovim!  
Paces through a buffer word-by-word with a highlight, at a configurable speed.

## Usage

```vim
:PacerStart [speed_ms]
:PacerPause
:PacerResume
:PacerResumeCursor
```

Stop and resumes automatically if you edit or enter insert mode.

Setup (lazy.nvim example)
{
  "your-username/pacer.nvim",
  cmd = {"PacerStart", "PacerPause", "PacerResume", "PacerResumeCursor"},
}
