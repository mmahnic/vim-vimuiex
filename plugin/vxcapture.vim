if vxlib#load#IsLoaded( 'vxcapture' )
   finish
endif
call vxlib#load#SetLoaded( 'vxcapture', 1 )

" <id="vimuiex#vxcapture" require="popuplist||python&&(!gui_running||python_screen)">

command -nargs=+ -complete=command VxCmd call vimuiex#vxcapture#VxCmd_QArgs(<q-args>)
command VxMarks call vimuiex#vxcapture#VxMarks()
command VxDisplay call vimuiex#vxcapture#VxDisplay()
command VxTags call vimuiex#vxcapture#VxTags()
command -nargs=+ VxMan call vimuiex#vxcapture#VxMan_QArgs(<q-args>)
nmap <silent><unique> <Plug>VxMarks :VxMarks<cr>
imap <silent><unique> <Plug>VxMarks <Esc>:VxMarks<cr>
vmap <silent><unique> <Plug>VxMarks :<c-u>VxMarks<cr>
nmap <silent><unique> <Plug>VxDisplay :VxDisplay<cr>
imap <silent><unique> <Plug>VxDisplay <Esc>:VxDisplay<cr>
vmap <silent><unique> <Plug>VxDisplay :<c-u>VxDisplay<cr>
nmap <silent><unique> <Plug>VxTagStack :VxTags<cr>
imap <silent><unique> <Plug>VxTagStack <Esc>:VxTags<cr>
vmap <silent><unique> <Plug>VxTagStack :<c-u>VxTags<cr>
nmap <silent><unique> <Plug>VxSpellZeq :call vimuiex#vxcapture#VxSpellZeq()<cr>

