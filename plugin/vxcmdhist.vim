
let g:loadedPlug = get(g:, 'loadedPlug', {})
if get(g:loadedPlug, 'vxcmdhist', 0)
   finish
endif

let g:loadedPlug.vxcmdhist = -1

let g:plug_vxcmdhist = get(g:, 'plug_vxcmdhist', {})
let g:plug_vxcmdhist.add_default_map = get(g:plug_vxcmdhist, 'add_default_map', 1)

" <id="vimuiex#vxcmdhist" require="popuplist||python&&(!gui_running||python_screen)">

if g:plug_vxcmdhist.add_default_map
   cnoremap <pageup> <C-\>evimuiex#vxcmdhist#PopupHist()<cr>
   cnoremap <pagedown> <C-\>evimuiex#vxcmdhist#PopupHist()<cr>
endif

let g:loadedPlug.vxcmdhist = 1
