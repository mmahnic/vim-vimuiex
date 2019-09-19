if vxlib#load#IsLoaded( 'vxcmdhist' )
   finish
endif
call vxlib#load#SetLoaded( 'vxcmdhist', 1 )

let g:plug_vxcmdhist = get(g:, 'plug_vxcmdhist', {})
let g:plug_vxcmdhist.add_default_map = get(g:plug_vxcmdhist, 'add_default_map', 1)

" <id="vimuiex#vxcmdhist" require="popuplist||python&&(!gui_running||python_screen)">

if g:plug_vxcmdhist.add_default_map
   cnoremap <pageup> <C-\>evimuiex#vxcmdhist#PopupHist()<cr>
   cnoremap <pagedown> <C-\>evimuiex#vxcmdhist#PopupHist()<cr>
endif
