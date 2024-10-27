local M = {}
M.model = nil

--
-- File
--

local function write_to_temp_file(content)
    local tmpfile = os.tmpname()  -- Generate a temporary file name
    local file = io.open(tmpfile, "w")
    if file then
        file:write(content)
        file:close()
    else
        vim.notify("Failed to write to temporary file.", vim.log.levels.ERROR)
    end
    return tmpfile
end

--
-- Window
--

local function open_vertical_split_with_content(content)
    local new_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(new_buf, 0, -1, false, vim.split(content, "\n"))
    local win = vim.api.nvim_get_current_win()
    vim.cmd('vsplit')
    vim.api.nvim_win_set_buf(win, new_buf)
    return new_buf
end

local function show_floating_window(message)
    -- Create a new buffer (do not list, scratch buffer)
    local float_buf = vim.api.nvim_create_buf(false, true)
    if not float_buf then
        vim.notify("Failed to create buf", vim.log.levels.ERROR)
    end

    -- Set the content to the provided message
    vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, {message})

    -- Define the floating window dimensions
    local width = #message + 2
    local height = 1
    local opts = {
        style = "minimal",
        relative = "editor",
        width = width,
        height = height,
        col = (vim.o.columns - width) / 2,
        row = (vim.o.lines - height) / 2,
        border = 'rounded' -- Optional: add a border to the floating window
    }
    -- Open the floating window
    local float_win = vim.api.nvim_open_win(float_buf, true, opts)
    if not float_win then
        vim.notify("Failed to open win", vim.log.levels.ERROR)
    end
    -- Optional: Set some window options, here the highlight group
    vim.api.nvim_win_set_option(float_win, 'winhl', 'Normal:Normal')

    return { win = float_win, buf = float_buf }
end

local function close_floating_window(f_win, f_buf)
    if f_win ~= nil and vim.api.nvim_win_is_valid(f_win) then
        vim.api.nvim_win_close(f_win, true)
    end
    if f_buf ~= nil and vim.api.nvim_buf_is_valid(f_buf) then
        vim.api.nvim_buf_delete(f_buf, {force=true})
    end
end

--
-- Selection
--
local function get_prompt(opts)
    local range = {}
    local is_cont = false
    if opts.range ~= 0 then
        -- First call, there is selected text
        local start_line = opts.line1
        local end_line = opts.line2
        if start_line == 0 and end_line == 0 then
            vim.notify("No range provided.", vim.log.levels.WARN)
            return nil
        end
        lines = vim.fn.getline(start_line, end_line)
        if #lines == 0 then
            vim.notify("No text in the provided range.", vim.log.levels.WARN)
            return nil
        end
    else
        -- Continue the chat, we should be in the chat buffer
        lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        if #lines == 0 then
            vim.notify("No text in buffer", vim.log.levels.WARN)
            return nil
        end
        local first_line = lines[1]
        local indicator = "user>"
        if string.sub(first_line, 1, #indicator) ~= indicator then
            vim.notify("Can only continue chat in chat buffer", vim.log.levels.WARN)
            return nil
        end
		vim.api.nvim_buf_set_lines(0, -1, -1, false, { "", "assistant>", "" })
        is_cont = true
    end

    return {
        lines = lines,
        len = #lines,
        is_cont = is_cont,
    }
end

--
-- MAIN
--

local incomplete_line = nil

-- opts is what nvim gives to nvim_create_user_command's function
function M.run(opts, range)
    local llm_cmd = opts.fargs[1]
    local prompt_obj = get_prompt(opts)
    if prompt_obj == nil then
        return
    end

    local user_win = vim.api.nvim_get_current_win()
    local popup = show_floating_window("Thinking...")
    vim.api.nvim_set_current_win(user_win)

    local content = table.concat(prompt_obj.lines, "\n")
    local tmpfile = write_to_temp_file(content)
    if tmpfile == nil then
        close_floating_window(popup.win, popup.buf)
        return
    end

    local output_buf = nil
    local on_exit = function(obj)
		local on_exit_action = function()
			vim.api.nvim_buf_set_lines(
				output_buf,
				-1,
				-1,
				false,
				{ "user>" }
			)
            close_floating_window(popup.win, popup.buf)
            vim.fn.delete(tmpfile)
        end
		vim.schedule_wrap(on_exit_action)()
    end

	local on_stdout = function(err, data)
		if not data or #data == 0 then
			return
		end

		local update_display = function()
			-- Add the incomplete part from previous call
			if incomplete_line then
				data = incomplete_line .. data
			end
			-- nvim_buf_set_lines wants an array of lines with not \n
			local parts = vim.split(data, "\n", { plain = true, trimempty = false })
			-- Handle the last part (could be incomplete)
			if data:sub(-1) ~= "\n" then
				-- If the data doesn't end with a newline, save the last part as incomplete
				incomplete_line = parts[#parts]
			else
				-- If it ends with a newline, there's no incomplete line
				incomplete_line = nil
			end
			-- We either saved it in incomplete_line, or it's just a carriage return
			table.remove(parts, #parts)
			if #parts ~= 0 then
				-- Update the display
				vim.api.nvim_buf_set_lines(output_buf, -1, -1, false, parts)
			end
		end
		vim.schedule_wrap(update_display)()
	end

    --local full_cmd = string.format("echo -n 'I am' && sleep 1 && echo -n ' the first' && sleep 1 && echo ' part' && sleep 1 && echo '' && sleep 1 && echo -n 'I am the second\nNow me is ' && sleep 1 && echo 'final'")
    local full_cmd = string.format("cat %s | %s", tmpfile, llm_cmd)
    if M.model then
        full_cmd = full_cmd:gsub("{MODEL}", M.model)
    end
    vim.system({"bash", "-c", full_cmd}, {text = true, stdout = on_stdout}, on_exit)

    if prompt_obj.is_cont then
        output_buf = vim.api.nvim_get_current_buf()
    else
        -- We need a new buffer
        output_buf = open_vertical_split_with_content(
            string.format("user>\n%s\n\nassistant>\n", content)
        )
    end

end

-- String "{MODEL}" in prompt will be replaced with this
function M.set_model(opts)
	M.model = opts.fargs[1]
	vim.notify(string.format("Calum model set to '%s'", M.model))
end

-- NVIM CMD is in plugin/init.lua

return M
