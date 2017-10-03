
let g:loadedPlug = get(g:, 'loadedPlug', {})
if get(g:loadedPlug, 'vxwatch', 0)
   finish
endif
let g:loadedPlug.vxwatch = -1

" <id="vimuiex#vxwatch" require="popuplist">

command -complete=var -nargs=1 VxWatch call vimuiex#vxwatch#VxWatch(<args>, <q-args>)
command VxWatchAll call vimuiex#vxwatch#VxWatchAll()

let g:loadedPlug.vxwatch = 1
