if vxlib#load#IsLoaded( 'vxquickfix' )
   finish
endif
call vxlib#load#SetLoaded( 'vxquickfix', 1 )

" <id="vimuiex#vxquickfix" require="popuplist">

command VxQfErrors call vimuiex#vxquickfix#VxQuickFixPuls('copen')
command VxQfLocations call vimuiex#vxquickfix#VxQuickFixPuls('lopen')

