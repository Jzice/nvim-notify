local M = {}

function M.setup()
  vim.cmd([[
    hi default NotifyERRORBorder guifg=#8A1F1F
    hi default NotifyWARNBorder guifg=#79491D
    hi default NotifyINFOBorder guifg=#4F6752
    hi default NotifyDEBUGBorder guifg=#8B8B8B
    hi default NotifyTRACEBorder guifg=#4F3552
    hi default NotifyERRORIcon ctermfg=DarkRed guifg=#F70067
    hi default NotifyWARNIcon ctermfg=DarkYellow guifg=#F79000
    hi default NotifyINFOIcon ctermfg=DarkGreen guifg=#A9FF68
    hi default NotifyDEBUGIcon guifg=#8B8B8B
    hi default NotifyTRACEIcon guifg=#D484FF
    hi default NotifyERRORTitle ctermfg=DarkRed guifg=#F70067
    hi default NotifyWARNTitle ctermfg=DarkYellow guifg=#F79000
    hi default NotifyINFOTitle ctermfg=DarkGreen guifg=#A9FF68
    hi default NotifyDEBUGTitle  guifg=#8B8B8B
    hi default NotifyTRACETitle  guifg=#D484FF
    hi default link NotifyERRORBody Normal
    hi default link NotifyWARNBody Normal
    hi default link NotifyINFOBody Normal
    hi default link NotifyDEBUGBody Normal
    hi default link NotifyTRACEBody Normal

    hi default link NotifyLogTime Comment
    hi default link NotifyLogTitle Special
  ]])
end

M.setup()

vim.cmd([[
  augroup NvimNotifyRefreshHighlights
    autocmd!
    autocmd ColorScheme * lua require('notify.config.highlights').setup()
  augroup END
]])

return M
