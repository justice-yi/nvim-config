-- 追加 treesitter 语法解析器(在 LazyVim 默认列表上追加,不会覆盖默认项)
-- xml/python 默认已含,写上作幂等保险;make 默认没有,必须显式加
return {
  "nvim-treesitter/nvim-treesitter",
  opts = function(_, opts)
    vim.list_extend(opts.ensure_installed, { "make", "xml", "python" })
  end,
}
