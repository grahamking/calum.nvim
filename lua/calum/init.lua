local M = {}
M.model = nil
M.config = {}

local defaults = {
  -- Key to activate Calum
  key = '<leader>l',

  -- All the available models. Must match a choice from `llm models`.
  -- First one in the list is default
  models = {'4o-mini', 'chatgpt-4o-latest'},

  -- Cmd line to do a query
  query_cmd = 'llm -m {MODEL} -o temperature 0.2',

  -- Cmd line with system prompt to do a code review
  review_cmd = 'llm -m {MODEL} -o temperature 0.2 -s \'You are a code review tool. You will be given snippets of code which you will review. You first identify the language of the snippet, then you provide helpful precise comments and suggestions for improvements. For each suggestion provide a recommended code change, if approriate. Be concise.\'',

  -- Cmd line with system prompt to do a fill-in-the-middle completion.
  fill_cmd = 'llm -m {MODEL} -o temperature 0.2 -s \'You are a fill-in-the-middle coding assistant. Given a prefix and suffix, return only the best middle. Return only the raw unquoted code. Do not wrap it in backticks.\''
}

-- Let use select from M.config.models (setup) which to use now.
-- String "{MODEL}" in prompt will be replaced with that string
local function do_switch_model()
  local available_models = M.config.models

  -- Basic validation: Check if models are configured
  if not available_models or #available_models == 0 then
    vim.notify("[calum.nvim] No models configured in setup!", vim.log.levels.ERROR)
    return
  end

  local opts = {
    prompt = "Select Model (Current: " .. (M.model or "None") .. "):",
  }

  local function on_model_choice(choice, index)
    -- Handle cancellation
    if not choice then
      return
    end
    M.model = choice
  end

  -- Show the model selection menu, but let the previous menu be cleared
  vim.defer_fn(function()
	  vim.ui.select(available_models, opts, on_model_choice)
  end, 0)
end

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
        vim.notify("[calum.nvim] Failed to write to temporary file.", vim.log.levels.ERROR)
		return nil
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

--
-- Selection
--
local function get_prompt(opts)
    local range = {}
    if opts.range > 0 then
		-- Send only the selected range
        local start_line = opts.line1
        local end_line = opts.line2
        if start_line == 0 and end_line == 0 then
            vim.notify("[calum.nvim] No range provided.", vim.log.levels.WARN)
            return nil
        end
        lines = vim.fn.getline(start_line, end_line)
        if #lines == 0 then
            vim.notify("[calum.nvim] No text in the provided range.", vim.log.levels.WARN)
            return nil
        end
    else
		-- Send the whole file
        lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        if #lines == 0 then
            vim.notify("[calum.nvim] No text in buffer", vim.log.levels.WARN)
            return nil
        end
    end
    return { lines = lines }
end

--
-- MAIN
--


-- opts is what nvim gives to nvim_create_user_command's function
-- Used for both Query and Review, with different `llm_cmd`.
function M.do_query(opts, range, llm_cmd)
    local prompt_obj = get_prompt(opts)
    if prompt_obj == nil then
        return
    end

	-- Are we continuing the chat in the split window?
    local is_cont = false
	local first_line = prompt_obj.lines[1]
	local indicator = "user>"
	if string.sub(first_line, 1, #indicator) == indicator then
		vim.api.nvim_buf_set_lines(0, -1, -1, false, { "", "assistant>", "" })
		is_cont = true
	end

    local user_win = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(user_win)

    local content = table.concat(prompt_obj.lines, "\n")
    local tmpfile = write_to_temp_file(content)
    if tmpfile == nil then
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
            vim.fn.delete(tmpfile)
        end
		vim.schedule_wrap(on_exit_action)()
    end

	local incomplete_line = nil
	local on_stdout = function(err, data)
		if not data or #data == 0 then
			return
		end

		local update_display = function()
			-- Add the incomplete part from previous call
			if incomplete_line then
				data = incomplete_line .. data
			end
			-- nvim_buf_set_lines wants an array of lines with no \n
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

    --local full_cmd = string.format("echo -n 'I am' && sleep 1 && echo -n ' the {MODEL}' && sleep 1 && echo ' part' && sleep 1 && echo '' && sleep 1 && echo -n 'I am the second\nNow me is ' && sleep 1 && echo 'final'")
    local full_cmd = string.format("cat %s | %s", tmpfile, llm_cmd)
    if M.model then
        full_cmd = full_cmd:gsub("{MODEL}", M.model)
    end

    vim.system({"bash", "-c", full_cmd}, {text = true, stdout = on_stdout}, on_exit)

    if is_cont then
        output_buf = vim.api.nvim_get_current_buf()
    else
        -- We need a new buffer
        output_buf = open_vertical_split_with_content(
            string.format("user>\n%s\n\nassistant>\n", content)
        )
    end

end

-- Fill-in-the-middle at current cursor position
function M.do_fill(opts)
    local llm_cmd = M.config.fill_cmd

    -- Read the current cursor position in the document
    local target_win = vim.api.nvim_get_current_win()
	local target_buf = vim.api.nvim_win_get_buf(target_win)

	local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local insert_line, col = cursor_pos[1], cursor_pos[2]

    -- Select text from start of file to current cursor position, store in "prefix"
    local lines = vim.api.nvim_buf_get_lines(0, 0, insert_line, false)
    local prefix = table.concat(lines, "\n")
    if #lines > 0 then
        prefix = prefix .. "\n" .. string.sub(lines[#lines], 1, col)
    end

    -- Select text from current cursor position to end of file, store in "suffix"
    local end_lines = vim.api.nvim_buf_get_lines(0, insert_line - 1, -1, false)
    local suffix = ""
    if #end_lines > 0 then
        suffix = string.sub(end_lines[1], col + 1)
        if #end_lines > 1 then
            suffix = suffix .. "\n" .. table.concat(end_lines, "\n", 2)
        end
    end

	-- Show that we're working
	vim.api.nvim_buf_set_lines(target_buf, insert_line, insert_line, false, {"===> Filling <==="})

    -- Identify the programming language based on neovim's auto detection, store in "language"
    local language = vim.bo.filetype

    local content = string.format("Language: %s\n\nPrefix:\n```\n%s\n```\n\nSuffix:\n```\n%s\n```\n\nMiddle:\n", language, prefix, suffix);
	local tmpfile = write_to_temp_file(content)
    if tmpfile == nil then
        return
    end

    local full_cmd = string.format("cat %s | %s", tmpfile, llm_cmd)
    if M.model then
        full_cmd = full_cmd:gsub("{MODEL}", M.model)
    end

	-- We have the command, now run it

	local data_so_far = ""
    local on_exit = function(obj)
		local on_exit_action = function()
			-- nvim_buf_set_lines wants an array of lines with no \n
			local parts = vim.split(data_so_far, "\n", { plain = true, trimempty = false })
			-- Check the buffer hasn't been closed
			if vim.api.nvim_buf_is_valid(target_buf) then
				vim.api.nvim_buf_set_lines(target_buf, insert_line - 1, insert_line + 1, false, parts)
			end
			data_so_far = ""
            vim.fn.delete(tmpfile)
        end
		vim.schedule_wrap(on_exit_action)()
    end

	local on_stdout = function(err, data)
		if not data or #data == 0 then
			return
		end
		-- Collect. We don't stream.
		data_so_far = data_so_far .. data
	end

    vim.system({"bash", "-c", full_cmd}, {text = true, stdout = on_stdout}, on_exit)

end

--
-- Main
--

function M.run_calum(opts, range)
  local menu_items = {
    "Query",
    "Fill",
    "Review",
    "Switch Model",
  }
  local actions = {
	-- Ask AI a question.
    ["Query"] = function() M.do_query(opts, range, M.config.query_cmd) end,
	-- Fill in at current cursor position
    ["Fill"] = function() M.do_fill(opts) end,
	-- Code review
    ["Review"] = function() M.do_query(opts, range, M.config.review_cmd) end,
	-- Choose a different model from the list passed in setup
    ["Switch Model"] = do_switch_model,
  }
  local opts = {
	-- Prompt displayed above the choices
    -- prompt = "Calum:",
    -- Optional: format items if needed (default usually shows numbers)
    -- format_item = function(item) return "- " .. item end,
  }

  -- Callback function for when the user makes a selection
  local function on_choice(choice, index)
    -- If user cancels (e.g., presses Esc), choice will be nil
    if not choice then
      return
    end
    local action_func = actions[choice]
    if action_func then
      action_func()
    else
      -- This shouldn't happen if the menu_items and actions keys match
      vim.notify("[calum.nvim] Error: Unknown action selected: " .. choice, vim.log.levels.ERROR)
    end
  end

  -- Show the menu
  vim.ui.select(menu_items, opts, on_choice)

end

--
-- Setup
--
function M.setup(opts)
  opts = opts or {}

  -- Merge the user's options table 'opts' with the 'defaults' table.
  local config = vim.tbl_deep_extend('force', {}, defaults, opts)
  M.config = config

  if M.config.models and #M.config.models > 0 then
    M.model = M.config.models[1]
  else
    -- Handle case where user provided empty models list or defaults were bad
    M.model = nil
    vim.notify("[calum.nvim] Warning: Invalid configuration, models cannot be empty.", vim.log.levels.WARN)
	return
  end

  vim.api.nvim_create_user_command('Calum', M.run_calum, {range = true, nargs = 0})

  vim.api.nvim_set_keymap('v', M.config.key, ':Calum<CR>', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('n', M.config.key, ':Calum<CR>', { noremap = true, silent = true })

end

return M
