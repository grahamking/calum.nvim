vim.api.nvim_create_user_command('Calum', function(opts)
    require('calum').run(opts)
end, {range = true, nargs = 1})

vim.api.nvim_create_user_command('CalumSetModel', function(opts)
    require('calum').set_model(opts)
end, {nargs = 1})

vim.api.nvim_create_user_command('CalumFill', function(opts)
	require('calum').fill(opts)
end, {nargs = 1})

