# pacer.nvim

## Intro

A reading pacer for Neovim to help you read faster!

This plugin adds a reading pacer to help focus your eyes on the current word while reading in Neovim. It alters the background and foreground colors of the current word as well as applies configurable text styling to make it obvious and "shiny" for your eyes to focus on. This helps you read substantially faster (with some practice and getting used to) by reducing the amount of time your eyes spend moving around the screen rather than on the line of text you are actually reading. Once adapted to pacer-based reading, many users find they can read significantly faster, often 2-3x their normal reading speed!

This plugin aims to bring pacer-based reading to Neovim that is ready to go out of the box but also fully configurable.

## Commands

```vim
:PacerStart             -- Starts the pacer with your default configuration
:PacerStart [wpm]       -- Starts the pacer with a specific WPM (words per minute) value
:PacerStart [Preset]    -- Starts the pacer with one of your configuration presets
:PacerPause             -- Saves the current position and pauses the pacer
:PacerStop              -- Stops the pacer and resets the position
:PacerResume            -- Resumes the pacer from the last saved position
```

## Config

Setup (for lazy.nvim):

```lua
return {
  "your-username/pacer.nvim",
  cmd = { "PacerStart", "PacerResume" },
  -- Plugin will be automatically loaded when any of the above commands are used
  -- You can also add keys or events for other loading triggers:
  -- keys = { "<leader>p" }, -- e.g., load on key mapping
  -- event = "BufRead", -- e.g., load when reading any buffer
  init = function()
    -- Ensure commands are available immediately
    vim.api.nvim_create_user_command("PacerStart", function() 
      require("pacer.commands").start_pacer({args = ""}) 
    end, { nargs = "?", desc = "Start the pacer" })
    vim.api.nvim_create_user_command("PacerPause", function() 
      require("pacer.commands").pause_pacer() 
    end, { desc = "Pause the pacer" })
    vim.api.nvim_create_user_command("PacerResume", function() 
      require("pacer.commands").resume_pacer() 
    end, { desc = "Resume the pacer" })
    vim.api.nvim_create_user_command("PacerStop", function() 
      require("pacer.commands").stop_pacer() 
    end, { desc = "Stop the pacer" })
  end,
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

### Additional keybindings

Increase Pacer speed:       `<C-.>`
Decrease Pacer speed:       `<C-,>`

Jump to next paragraph:     `<C-n>`
Jump to previous paragraph: `<C-p>`

## Roadmap

1. Add blackbox tests to cover existing behaviors.
1. Refactor the code to make it more readable, maintainable. Also add type definitions.
1. Increase configurability, e.g. for additional keybindings.
1. Auto-detect current text fg and bg colors to automatically set proper current-word highlighting and dimming colors?
