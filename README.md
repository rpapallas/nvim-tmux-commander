<h1 align="center"> nvim-tmux-commander</h1>

This is a simple plugin, inspired by the [Harpoon](https://github.com/ThePrimeagen/harpoon) project,
to register and run commands. It will launch a pane dedicated to run commands. The user can
define custom commands (bash/zsh commands) and the plugin will run them using
keybindings.

## Installation

```lua
return {
    "rpapallas/nvim-tmux-commander",
    dependencies = {
        'nvim-lua/plenary.nvim',
    },
    keys = function()
        local ntc = require('nvim-tmux-commander')

        return {
            {
                "<leader>c",
                function() ntc.register_command() end,
                desc = "This will prompt the user to type in a command to register."
            },
            {
                "<leader>l",
                function() ntc.list_commands() end,
                desc = "This will show a pop up window displaying the current registered commands."
            },
            {
                "<leader>q",
                function() ntc.run(1) end,
                desc = "This will run the first command."
            },
            {
                "<leader>w",
                function() ntc.run(2) end,
                desc = "This will run the second command"
            },
            -- ... here add as many ntc.run(i) you want, just be creative with your keybindings.
            {
                "<leader>k",
                function() ntc.kill() end,
                desc = "This will kill the runner pane."
            },
        }
    end,
    opts = {
    },
}
```

## Contributions, feedback and requests

Happy to accept contributions/pull requests to extend and improve this simple
plugin. I am also open to feedback and requests for new features. Please open a
GitHub issue for those.

## TODO

This is currently in very early stage development. Happy to receive feedback, PRs etc. Some things I plan to add/fix:

- [ ] More robust runner pane handling.
- [ ] Customisation via a config file (allowing a user to define customisation via the `opts` dictionary). For example, the pop-up dimensions, the runner pane dimensions etc.
