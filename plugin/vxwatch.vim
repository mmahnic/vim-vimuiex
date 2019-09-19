if vxlib#load#IsLoaded( 'vxwatch' )
   finish
endif
call vxlib#load#SetLoaded( 'vxwatch', 1 )

" <id="vimuiex#vxwatch" require="popuplist">

command -complete=var -nargs=1 VxWatch call vimuiex#vxwatch#VxWatch(<args>, <q-args>)
command VxWatchAll call vimuiex#vxwatch#VxWatchAll()

