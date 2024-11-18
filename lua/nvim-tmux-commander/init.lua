local M = {}
local config = require("nvim-tmux-commander.config")
local popup = require("plenary.popup")

function M.setup(options)
    config.setup(options)
end

local session_file = vim.fn.stdpath("data") .. "/nvim-tmux-commander.json"
local session_data = {}

local function read_json_file(path)
    local file = io.open(path, "r")
    if not file then
        return {}
    end
    local content = file:read("*a")
    file:close()
    return vim.json.decode(content) or {}
end

local function write_json_file(path, data)
    local file = io.open(path, "w")
    if not file then
        error("Could not write to " .. path)
    end
    file:write(vim.json.encode(data))
    file:close()
end

local function save_sessions()
    write_json_file(session_file, session_data)
end

local function execute_tmux_command(command)
    local handle = io.popen("tmux " .. command .. " 2>&1")
    local result = handle:read("*a")
    handle:close()
    return result:match("^%s*(.-)%s*$") -- Trim whitespace
end

local function pane_exists(pane_name)
    local panes = execute_tmux_command("list-panes -F '#{pane_title} #{pane_active}'")
    for line in string.gmatch(panes, "[^\r\n]+") do
        local name, active = line:match("^(%S+)%s+(%d+)$")
        if name == pane_name and active ~= "dead" then
            return true
        end
    end
    return false
end

local function focus_vim_pane(vim_pane_id)
    execute_tmux_command("select-pane -t " .. vim_pane_id)
end

function M.register_command()
    session_data = read_json_file(session_file)
    local cwd = vim.loop.cwd()

    session_data[cwd] = session_data[cwd] or {}
    session_data[cwd].commands = session_data[cwd].commands or {}

    local command = vim.fn.input("Enter the command to run: ")

    table.insert(session_data[cwd].commands, command)
    save_sessions()
    print("Command registered: " .. command)
end

local function create_window(title, width, height)
    local bufnr = vim.api.nvim_create_buf(false, true) -- Set the buffer as modifiable

    local borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }

    local win_id, win = popup.create(bufnr, {
        title = title,
        highlight = "NTCWindow",
        line = math.floor(((vim.o.lines - height) / 2) - 1),
        col = math.floor((vim.o.columns - width) / 2),
        minwidth = width,
        minheight = height,
        borderchars = borderchars,
    })

    vim.api.nvim_win_set_option(
        win.border.win_id,
        "winhl",
        "Normal:NTCBorder"
    )

    return {
        bufnr = bufnr,
        win_id = win_id,
    }
end

function M.list_commands()
    session_data = read_json_file(session_file)
    local cwd = vim.loop.cwd()

    session_data[cwd] = session_data[cwd] or {}
    session_data[cwd].commands = session_data[cwd].commands or {}

    local commands = session_data[cwd].commands
    local lines = {}

    for _, cmd in ipairs(commands) do
        table.insert(lines, cmd)
    end

    local width = 60
    local height = math.min(#lines + 2, 20)

    local win_info = create_window("nvim-tmux-commander", width, height)
    local bufnr = win_info.bufnr

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
    vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")

    local function save_changes()
        local new_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) -- Skip the title line
        session_data[cwd].commands = new_lines -- Save all updated commands
        write_json_file(session_file, session_data)
        print("Commands updated and saved.")
    end

    vim.api.nvim_buf_set_keymap(bufnr, "n", "q", ":lua require('nvim-tmux-commander').save_and_close()<CR>", { noremap = true, silent = true })

    M.save_and_close = function()
        save_changes()
        vim.api.nvim_win_close(win_info.win_id, true)
    end
end

function M.run(index)
    session_data = read_json_file(session_file)
    local cwd = vim.loop.cwd()

    if not session_data[cwd] or not session_data[cwd].commands then
        print("No commands registered for the current directory.")
        return
    end

    local pane_name = "runner"
    local command = session_data[cwd].commands[index]

    if not command then
        print("Invalid command index: " .. index)
        return
    end

    -- Save the current Vim pane index
    local vim_pane_id = execute_tmux_command("display-message -p '#{pane_id}'")

    if pane_exists(pane_name) then
        execute_tmux_command("send-keys -t '" .. session_data[cwd].rid .. "' \"" .. command .. "\" C-m")
    else
        execute_tmux_command("split-window -v -p 30")
        execute_tmux_command("select-pane -T '" .. pane_name .. "'")
        local npid = execute_tmux_command("display-message -p '#{pane_id}'")

        session_data[cwd].rid = npid
        save_sessions()

        execute_tmux_command("send-keys \"" .. command .. "\" C-m")
    end

    focus_vim_pane(vim_pane_id)
end

function M.kill()
    session_data = read_json_file(session_file)
    local cwd = vim.loop.cwd()

    if not session_data[cwd] or not session_data[cwd].rid then
        print("No session or runner ID found for the current directory.")
        return
    end

    local pane_id = session_data[cwd].rid

    execute_tmux_command("kill-pane -t '" .. pane_id .. "'")

    -- Clean up session data
    session_data[cwd].rid = nil
    if vim.tbl_isempty(session_data[cwd]) then
        session_data[cwd] = nil
    end
    save_sessions()

    print("Runner pane '" .. pane_id .. "' has been killed.")
end

return M
