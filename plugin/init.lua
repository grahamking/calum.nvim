vim.api.nvim_create_user_command('Calum', function(opts)
    require('calum').run(opts)
end, {range = true, nargs = 1})
