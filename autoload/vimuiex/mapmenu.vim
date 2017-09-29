" vim:set fileencoding=utf-8 sw=3 ts=8 et
" mapmenu.vim - display a menu of possible key sequences that complete the
"               current sequence
"
" Author: Marko Mahnič
" Created: November 2014
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.

if vxlib#plugin#StopLoading('#au#vimuiex#mapmenu')
   finish
endif

let s:KeyMenuItems = {}
let s:capture = []

function! vimuiex#mapmenu#ShowKeyMenu(mapcmd, mapprefix)
   " if there is a key waiting, we (probably) have a wrong sequence; exit
   if getchar(1) != 0
      return
   endif

   " capture the keymap for the map-prefix and create the menu items
   let maps = vxlib#cmd#Capture( a:mapcmd . ' ' . a:mapprefix, 1 )
   let text = ""
   let s:capture = []
   for m in maps
      let parts = split( m, ' \+', 1 )
      let key = parts[1]
      if key == a:mapprefix
         continue
      endif
      if has_key(s:KeyMenuItems, key)
         let text = s:KeyMenuItems[key]
      else
         let text = join(parts[2:], ' ')
         let text = substitute(text, '<Plug>', '', '')
      endif
      let dispkey = substitute(key, '^' . a:mapprefix, '', '')
      call add( s:capture, dispkey . "\t" . text )
   endfor

   call sort( s:capture )

   " display the menu items; when one of them is accepted, feed the full
   " sequence back to the input queue
   let title = 'Run command'
   if has('popuplist')
      let rslt = popuplist(s:capture, title)
      if rslt.status == 'accept'
         let sel = split(s:capture[rslt.current], "\t")[0]
         " echom 'len ' . len(sel). ', ' . kseq . ' /' . a:mapcmd[0] . ' -> ' . ekseq
         if len(sel) > 0
            " convert the keysequence to a binary string and pass it to feedkeys
            let kseq = a:mapprefix . sel
            let ekseq = substitute(kseq, '<\([^<>\s]\+\)>', '\\<\1>', 'g')
            let binseq = eval('"' . ekseq . '"')
            call feedkeys( binseq, 't' )
         endif
      endif
   "else
   "   call vimuiex#vxlist#VxPopup(s:capture, title)
   endif
endfunc

function! vimuiex#mapmenu#SetKeymapTitle(keymap, title)
   let s:KeyMenuItems[a:keymap] = a:title
endfunc
