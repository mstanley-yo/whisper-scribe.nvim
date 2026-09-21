-- Minimal init for running tests headlessly with plenary.nvim.
-- Assumes plenary.nvim is already installed somewhere under your normal
-- lazy.nvim plugin data dir; adjust plenary_path below if it lives elsewhere.
local plugin_root = vim.fn.fnamemodify(vim.fn.expand("<sfile>"), ":h:h")
vim.opt.runtimepath:append(plugin_root)

local plenary_path = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"
if vim.fn.isdirectory(plenary_path) == 1 then
  vim.opt.runtimepath:append(plenary_path)
end

require("plenary.busted")
