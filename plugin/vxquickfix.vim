
let g:loadedPlug = get(g:, 'loadedPlug', {})
if get(g:loadedPlug, 'vxquickfix', 0)
   finish
endif
let g:loadedPlug.vxquickfix = -1

" <id="vimuiex#vxquickfix" require="popuplist">

command VxQfErrors call vimuiex#vxquickfix#VxQuickFixPuls('copen')
command VxQfLocations call vimuiex#vxquickfix#VxQuickFixPuls('lopen')

let g:loadedPlug.vxquickfix = 1
