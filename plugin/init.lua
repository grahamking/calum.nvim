-- First argument must be a model name: `llm models` to see options
vim.api.nvim_create_user_command('Calum', function(opts)
	local model_name = opts.fargs[1]
	local range = {opts.line1, opts.line2}
    require('calum').run(model_name, range)
end, {range = true, nargs = 1})
