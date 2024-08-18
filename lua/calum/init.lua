local M = {}

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
		local indicator = "user> "
		if string.sub(first_line, 1, #indicator) ~= indicator then
			vim.notify("Can only continue chat in chat buffer", vim.log.levels.WARN)
			return nil
		end
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
		local buf_update = string.format("\nassistant>\n%s\nuser> ", obj.stdout)
		vim.defer_fn(function()
			vim.api.nvim_buf_set_lines(
				output_buf,
				prompt_obj.len + 1,
				-1,
				false,
				vim.split(buf_update, "\n")
			)
			close_floating_window(popup.win, popup.buf)
			vim.fn.delete(tmpfile)
		end, 0)
	end
	--local full_cmd = string.format("sleep 2 && echo I am the answer")
	local full_cmd = string.format("cat %s | %s", tmpfile, llm_cmd)
	vim.system({"bash", "-c", full_cmd}, {text = true}, on_exit)

	if prompt_obj.is_cont then
		output_buf = vim.api.nvim_get_current_buf()
	else
		-- We need a new buffer
		output_buf = open_vertical_split_with_content(
			string.format("user> %s", content)
		)
	end

end

-- NVIM CMD is in plugin/init.lua

return M
