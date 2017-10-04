
let g:loadedPlug = get(g:, 'loadedPlug', {})
if get(g:loadedPlug, 'vxtabs', 0)
   finish
endif
let g:loadedPlug.vxtabs = -1

" <id="vimuiex#vxtabs" require="popuplist||python&&(!gui_running||python_screen)">

command VxTabSelect call vimuiex#vxtabs#VxTabSelect()

let g:loadedPlug.vxtabs = 1
