if vxlib#load#IsLoaded( 'vxtextmenu' )
   finish
endif
call vxlib#load#SetLoaded( 'vxtextmenu', 1 )

" <id="vimuiex#vxtextmenu" require="popuplist||python&&(!gui_running||python_screen)">

command VxTextMenu call vimuiex#vxtextmenu#VxTextMenu('','n')
nmap <silent><unique> <Plug>VxTextMenu :call vimuiex#vxtextmenu#VxTextMenu('','n')<cr>
imap <silent><unique> <Plug>VxTextMenu <c-o>:call vimuiex#vxtextmenu#VxTextMenu('','i')<cr>
vmap <silent><unique> <Plug>VxTextMenu :<c-u>call vimuiex#vxtextmenu#VxTextMenu('','v',visualmode())<cr>

