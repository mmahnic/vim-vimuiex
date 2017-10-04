
let g:loadedPlug = get(g:, 'loadedPlug', {})
if get(g:loadedPlug, 'vxtextmenu', 0)
   finish
endif
let g:loadedPlug.vxtextmenu = -1

" <id="vimuiex#vxtextmenu" require="popuplist||python&&(!gui_running||python_screen)">

command VxTextMenu call vimuiex#vxtextmenu#VxTextMenu('','n')
nmap <silent><unique> <Plug>VxTextMenu :call vimuiex#vxtextmenu#VxTextMenu('','n')<cr>
imap <silent><unique> <Plug>VxTextMenu <c-o>:call vimuiex#vxtextmenu#VxTextMenu('','i')<cr>
vmap <silent><unique> <Plug>VxTextMenu :<c-u>call vimuiex#vxtextmenu#VxTextMenu('','v',visualmode())<cr>

let g:loadedPlug.vxtextmenu = 1
