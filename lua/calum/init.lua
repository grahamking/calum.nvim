local M = {}

--
-- FILE
--

local function write_to_temp_file(content)
    local tmpfile = os.tmpname()  -- Generate a temporary file name
    local file = io.open(tmpfile, "w")
    if file then
        file:write(content)
        file:close()
    else
        print("Failed to write to temporary file.")
    end
	return tmpfile
end

--
-- WINDOW
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
    -- Close the existing floating window if it exists
    --if float_win ~= nil and vim.api.nvim_win_is_valid(float_win) then
    --    close_floating_window(float_win, float_buf)
    --end

    -- Create a new buffer (do not list, scratch buffer)
    local float_buf = vim.api.nvim_create_buf(false, true)
	if not float_buf then
		vim.notify("failed to create buf", vim.log.levels.ERROR)
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
		vim.notify("failed to open win", vim.log.levels.ERROR)
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
-- MAIN
--

function M.run(model_name, range)

	-- TODO
	-- if there is not range
	--  and the buffer starts with "user>"
	-- then
	--  set a variable saying we're a continuation
	--  select the whole buffer

    if #range < 2 then
        print("Please provide a valid range.")
        return
    end

    local start_line = range[1]
    local end_line = range[2]

    if start_line == 0 and end_line == 0 then
        print("No range provided.")
        return
    end

    local lines = vim.fn.getline(start_line, end_line)
    if #lines == 0 then
        print("No text in the provided range.")
        return
    end
	local prompt_lines = #lines

    local user_win = vim.api.nvim_get_current_win()
	local popup = show_floating_window(string.format("Calling %s...", model_name))
	vim.api.nvim_set_current_win(user_win)

    local content = table.concat(lines, "\n")
    local tmpfile = write_to_temp_file(content)
    if tmpfile then
		local output_buf = nil
		local on_exit = function(obj)
			local buf_update = string.format("\nassistant>\n%s\nuser> ", obj.stdout)
			vim.defer_fn(function()
				vim.api.nvim_buf_set_lines(
					output_buf,
					prompt_lines + 1,
					-1,
					false,
					vim.split(buf_update, "\n")
				)

				close_floating_window(popup.win, popup.buf)

				vim.fn.delete(tmpfile)

			end, 0)
		end
		-- LLM_OPENAI_SHOW_RESPONSES=1 on cmd line to debug
		--local cmd = string.format("cat %s | llm -m %s -o max_tokens 1024", tmpfile, model_name)
		local cmd = string.format("sleep 2 && echo I am the answer")
		vim.system({"bash", "-c", cmd}, {text = true}, on_exit)

		-- TODO only add "user" if not a continuation
		output_buf = open_vertical_split_with_content(
			string.format("user> %s", content)
		)
	else
		close_floating_window(popup.win, popup.buf)
    end

end

-- NVIM CMD is in plugin/init.lua

return M
