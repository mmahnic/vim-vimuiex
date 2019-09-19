if vxlib#load#IsLoaded( 'vxmap' )
   finish
endif
call vxlib#load#SetLoaded( 'vxmap', 1 )

" <id="vimuiex#vxmap#quickkeys" require="menu">

function! s:Check(dict, path, setting, default)
   let val = a:dict
   for p in a:path 
      let val[p] = get(val, p, {})
      let val = val[p]
   endfor
   let val[a:setting] = get(val, a:setting, a:default)
   return val[a:setting]
endfunc

let g:plug_vxmap = get(g:, 'plug_vxmap', {})

" use 'default' to append; use 'default!' to replace
" each list item is: ['key', 'key', ...]
call s:Check(g:plug_vxmap, [], 'quick_keys', {'default!': ['<F5>', '<F6>', '<F7>']})

" dictionary of lists; use 'default' to append; use 'default!' to replace
" each list item is: ['menu entry', ['command', 'command', ...]]
call s:Check(g:plug_vxmap, [], 'quick_commands', {'default': []})

" vimuiex/popup/choice(/tlib, not yet)
call s:Check(g:plug_vxmap, [], 'quick_menu', 'popuplist')

let g:vxmap_quick_keys = g:plug_vxmap.quick_keys
let g:vxmap_quick_commands = g:plug_vxmap.quick_commands
let g:vxmap_quick_menu = g:plug_vxmap.quick_menu

nmap <silent><unique> <Plug>VxMapDefaultKeys :call vimuiex#vxmap#InstallKeys('default','default')<cr>
imap <silent><unique> <Plug>VxMapDefaultKeys <Esc>:call vimuiex#vxmap#InstallKeys('default','default')<cr>
vmap <silent><unique> <Plug>VxMapDefaultKeys <Esc>:call vimuiex#vxmap#InstallKeys('default','default')<cr>

