# pacer.nvim

## TODO

1. Add blackbox tests
1. Refactor everything because omg

## Intro

A fast-paced reading plugin for Neovim!  
Paces through a buffer word-by-word with a highlight, at a configurable speed.

## Commands

```vim
:PacerStart [wpm]
:PacerStart [Preset]
:PacerPause             -- saves the current position
:PacerStop              -- stops the pacer and resets the position
:PacerResume
```

## Config

Setup (for lazy.nvim):

```lua
return {
  "your-username/pacer.nvim",
  cmd = { "PacerStart", "PacerPause", "PacerResume" },
  opts = {
    -- Set the colors for the currently highlighted word
    highlight = {
      bg = "#335577",
      fg = "#ffffff",

      -- The style to apply to the currently highlighted word
      -- It can be any combination of the following: bold, italic, underline, undercurl
      style = "underline",
    },

    -- This is the default WPM (words per minute) to use when starting the pacer if no WPM or Preset is provided
    wpm = 300,

    -- The keyboard shortcut to pause the pacer. You can run `:PacerResume` to restart your existing pacer session,
    -- or `:PacerStart` to start a new session from the current position in the buffer.
    pause_key = "<C-c>",

    -- Determines if the cursor moves along with the pacer. If set to false, the pacer will highlight words without moving the cursor.
    -- You do _not_ need to set this to true to save your position!
    move_cursor = true,

    -- Sets a delay between each paragraph (or large change in code scope) to make transitions smoother.
    paragraph_delay_multiplier = 2,

    -- Sets the color of the dimmed text outside of the current paragraph or code scope.
    focus = {
      enabled = true,
      dim_color = "#777777",
    },

    -- Presets allow you to override all of your default settings in an easy way.
    -- For example, MyPreset could be a fast-paced reading preset that you can quickly switch to.
    -- They can override _any_ setting. Anything they do not override will use the default config.
    presets = {
      MyPreset = {
        wpm = 400,
      }
    }
  }
}
```

## Usage

Start the pacer with `:PacerStart` and pass in a WPM (words per minute) value or a preset. All presets are defined in your config and provide custom overrides of the default config provided for the plugin.

If you hit `<C-c>` while the pacer is running, it will pause and save the current position. You can then resume with `:PacerResume`.

If you run `:PacerStop`, it will stop the pacer and reset the position to the start of the buffer.

If you run `:PacerStart` while the Pacer is already running (or paused), it will start from the current position in the buffer with the updated settings.

As the pacer runs, it will highlight the current word and automatically scroll the window to keep the current word within the middle half of the screen. It will also dim text outside of the current paragraph or code scope to make it even easier to focus on the current word!
