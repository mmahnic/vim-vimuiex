if vxlib#load#IsLoaded( 'vxtabs' )
   finish
endif
call vxlib#load#SetLoaded( 'vxtabs', 1 )

" <id="vimuiex#vxtabs" require="popuplist||python&&(!gui_running||python_screen)">

command VxTabSelect call vimuiex#vxtabs#VxTabSelect()

