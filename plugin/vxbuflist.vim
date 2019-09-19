if vxlib#load#IsLoaded( 'vxbuflist' )
   finish
endif
call vxlib#load#SetLoaded( 'vxbuflist', 1 )

" <id="vimuiex#vxbuflist" require="popuplist||python&&(!gui_running||python_screen)">

let g:plug_vxbuflist = get(g:, 'plug_vxbuflist', {})
let g:plug_vxbuflist.use_internal = get(g:plug_vxbuflist, 'use_internal', 0)

let g:VxPluginVar.vxbuflist_mru = []
function s:VIMUIEX_buflist_pushBufNr(nr)
   " mru code adapted from tlib#buffer
   let lst = g:VxPluginVar.vxbuflist_mru
   let i = index(lst, a:nr)
   if i > 0  | call remove(lst, i) | endif
   if i != 0 | call insert(lst, a:nr) | endif
endfunc

augroup vxbuflist
   autocmd BufEnter * call s:VIMUIEX_buflist_pushBufNr(bufnr('%'))
augroup END
command VxBufListSelect call vimuiex#vxbuflist#VxBufListSelect()
nmap <silent><unique> <Plug>VxBufListSelect :VxBufListSelect<cr>
imap <silent><unique> <Plug>VxBufListSelect <Esc>:VxBufListSelect<cr>
vmap <silent><unique> <Plug>VxBufListSelect :<c-u>VxBufListSelect<cr>

