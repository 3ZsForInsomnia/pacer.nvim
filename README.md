# pacer.nvim

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
