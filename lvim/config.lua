local linters = require "lvim.lsp.null-ls.linters"
linters.setup {
  { command = "eslint", filetypes = { "typescript", "typescriptreact" } }
}

local formatters = require "lvim.lsp.null-ls.formatters"
formatters.setup {
  {
    command = "prettier",
    filetypes = { "typescript", "typescriptreact" },
  },
}

vim.wo.relativenumber = true

-- mappings
vim.api.nvim_set_keymap('i', 'kj', '<ESC>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('v', 'kj', '<ESC>', { noremap = true, silent = true })

-- Center line on PageUp and PageDown
vim.api.nvim_set_keymap('n', '<C-u>', '<C-u>zz', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<C-d>', '<C-d>zz', { noremap = true, silent = true })

-- Center line on search
vim.api.nvim_set_keymap('n', 'n', 'nzz', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'N', 'Nzz', { noremap = true, silent = true })

-- Movement in insert mode
vim.api.nvim_set_keymap('i', '<C-h>', '<Left>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('i', '<C-l>', '<Right>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('i', '<C-j>', '<Down>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('i', '<C-k>', '<Up>', { noremap = true, silent = true })

-- Swap lines function
_G.swap_lines = function(n1, n2)
    if n1 < 1 or n1 > vim.api.nvim_buf_line_count(0) or n2 < 1 or n2 > vim.api.nvim_buf_line_count(0) then
        return
    end

    local current_cursor = vim.api.nvim_win_get_cursor(0)
    local cursor_y_position = current_cursor[2]

    local line1 = vim.api.nvim_buf_get_lines(0, n1 - 1, n1, false)[1]
    local line2 = vim.api.nvim_buf_get_lines(0, n2 - 1, n2, false)[1]
    vim.api.nvim_buf_set_lines(0, n2 - 1, n2, false, {line1})
    vim.api.nvim_buf_set_lines(0, n1 - 1, n1, false, {line2})

    -- Move cursor with the line
    if n2 >= 1 and n2 <= vim.api.nvim_buf_line_count(0) then
        vim.api.nvim_win_set_cursor(0, {n2, cursor_y_position})
    end
end

-- Move line up
vim.api.nvim_set_keymap('n', '<C-k>', '<Cmd>lua swap_lines(vim.api.nvim_win_get_cursor(0)[1], vim.api.nvim_win_get_cursor(0)[1] - 1)<CR>', { noremap = true, silent = false })

-- Move line down
vim.api.nvim_set_keymap('n', '<C-j>', '<Cmd>lua swap_lines(vim.api.nvim_win_get_cursor(0)[1], vim.api.nvim_win_get_cursor(0)[1] + 1)<CR>', { noremap = true, silent = false })



lvim.builtin.which_key.mappings["t"] = {
  name = "+Terminal",
  f = { "<cmd>ToggleTerm<cr>", "Floating terminal" },
  v = { "<cmd>2ToggleTerm size=30 direction=vertical<cr>", "Split vertical" },
  h = { "<cmd>2ToggleTerm size=30 direction=horizontal<cr>", "Split horizontal" },
}

lvim.plugins = {
  { "lunarvim/colorschemes" },
   { "ThePrimeagen/vim-be-good" },
}

