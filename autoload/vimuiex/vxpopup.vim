" vim:set fileencoding=utf-8 sw=3 ts=3 et
" vxpopup.vim - Utilities for working with (filtered lists in) popup windows
"
" Author: Marko Mahnič
" Created: September 2019
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.

" A generic handler for (modal) popup window filters with actions defined in
" `keymaps`, a list of dictionaries or functions.
"
" If an element of the list is a dictionary its elements are <key, function>
" pairs where the function accepts the parameter winid as in filter option of
" popup_create.  The function element can be of type string or funcref.
"
" If an element of the list is a function, it behaves the same as a normal
" popup filter function.  If it returns v:true, key processing is stopped and
" no futher elements form the `keymaps` list are processed.
" NOTE: this will cause problems if key-sequence disambiguation is introduced.
"
" This design enables us to compose keymaps from smaller keymaps and to
" override mappings of the default keymaps.
"
" `key_filter` always returns v:true. See implications in `popup-filter` help.
"
" Example:
"    let keymaps = [ {
"       \ "\<esc>" : { winid -> popup_close( winid ) },
"       \ "\<cr>" : "GlobalPopupAccept"
"       \ } ]
"    let winid = popup_dialog( s:GetBufferList(), #{
"       \ filter: { win, key -> vimuiex#vxpopup#key_filter( win, key, keymaps ) },
"       \ title: s:GetTitle(),
"       \ cursorline: 1,
"       \ } )
function! vimuiex#vxpopup#key_filter( winid, key, keymaps )
   for Keymap in a:keymaps
      if type( Keymap ) == v:t_func
         " Keymap is a filter-like function. If it handles the key (returns
         " true), stop processing further keymaps.
         if Keymap( a:winid, a:key )
            break
         endif
      elseif has_key( Keymap, a:key )
         " Keymap is a dictionary and an entry for the key is present in it.
         let FilterFunc = Keymap[a:key]
         if type( FilterFunc ) == v:t_func
            call FilterFunc( a:winid )
         elseif type( FilterFunc ) == v:t_string
            exec "call " . FilterFunc . "(" . a:winid . ")"
         endif
         break
      endif
   endfor

   return v:true
endfunc

function! vimuiex#vxpopup#down( winid )
   call win_execute( a:winid, "normal! +" )
endfunc

function! vimuiex#vxpopup#up( winid )
   call win_execute( a:winid, "normal! -" )
endfunc

function! vimuiex#vxpopup#page_down( winid )
   call win_execute( a:winid, "normal! \<C-F>" )
endfunc

function! vimuiex#vxpopup#page_up( winid )
   call win_execute( a:winid, "normal! \<C-B>" )
endfunc

function! vimuiex#vxpopup#scroll_left( winid )
   " call win_execute( a:winid, "normal! 0" )
   call popup_setoptions( a:winid, #{ wrap: 0 } )
endfunc

function! vimuiex#vxpopup#scroll_right( winid )
   " call win_execute( a:winid, "normal! $" )
   " FIXME: workaround: can not scroll l/r, so we wrap to see the whole line, instead.
   call popup_setoptions( a:winid, #{ wrap: 1 } )
endfunc

function! vimuiex#vxpopup#select_line( winid, line )
   call win_execute( a:winid, ":" . a:line )
endfunc

" TODO: rename to get_current_index, return line()-1
function! vimuiex#vxpopup#get_current_line( winid )
   let curidx = line( '.', a:winid ) - 1
   let vxlist = getwinvar( a:winid, "vxpopup_list" )
   if type( vxlist ) != v:t_dict
      return curidx + 1
   endif
   let globalIndex = s:map_visible_to_global( vxlist, curidx )
   if globalIndex > 0
      return globalIndex + 1
   endif
   return globalIndex
endfunc

let s:list_keymap = {
         \ 'j': { win -> vimuiex#vxpopup#down( win ) },
         \ 'k': { win -> vimuiex#vxpopup#up( win ) },
         \ 'h': { win -> vimuiex#vxpopup#scroll_left( win ) },
         \ 'l': { win -> vimuiex#vxpopup#scroll_right( win ) },
         \ 'n': { win -> vimuiex#vxpopup#page_down( win ) },
         \ 'p': { win -> vimuiex#vxpopup#page_up( win ) },
         \ 'f': { win -> s:popup_filter( win ) },
         \ "\<esc>" : { win -> popup_close( win ) }
         \ }

function! vimuiex#vxpopup#popup_list( items, options )
   let current = 1
   let keymaps = [s:list_keymap]
   if has_key( a:options, 'vxcurrent' )
      let current = a:options.vxcurrent
      unlet a:options.vxcurrent
      if type(current) != v:t_number
         let current = 1
      endif
   endif
   if has_key( a:options, 'vxkeymap' )
      let keymaps = a:options.vxkeymap + keymaps
      unlet a:options.vxkeymap
   endif

   let maxwidth = &columns - 6
   if has_key( a:options, 'maxwidth' ) && a:options.maxwidth < maxwidth
      let maxwidth = a:options.maxwidth
   endif
   let a:options.maxwidth = maxwidth

   let maxheight = &lines - 6
   if has_key( a:options, 'maxheight' ) && a:options.maxheight < maxheight
      let maxheight = a:options.maxheight
   endif
   let a:options.maxheight = maxheight

   let selector = ''
   if has_key( a:options, 'vxselector' )
      let selector = a:options['vxselector']
   endif

   let a:options.wrap = 0

   let a:options.filter = { win, key -> vimuiex#vxpopup#key_filter( win, key, keymaps ) }
   let a:options.cursorline = 1
   let a:options.hidden = 1
   let winid = popup_dialog( "", a:options )
   let vxlist = #{
            \ windowid: winid,
            \ content: a:items,
            \ selector: selector
            \ }
   call setwinvar( winid, 'vxpopup_list', vxlist )
   call s:popup_list_update_content( vxlist )
   if current > 1
      let index = s:map_global_to_visible( vxlist, current )
      call vimuiex#vxpopup#select_line( winid, index )
   endif
   call popup_show( winid )
   return winid
endfunc

" global -> displayed -> visible
" global: all the available items
" displayed: the items that match the selector are displayed
" visible: the visible part of the list

function! s:map_global_to_visible( vxlist, globalIndex )
   if a:vxlist.selector == ""
      return a:globalIndex
   endif
   if len(a:vxlist.selected) == 0
      return -1
   endif
   for idx in a:vxlist.selected
      if idx >= a:globalIndex
         return idx
      endif
   endfor
   return a:vxlist.selected[-1]
endfunc

function! s:map_visible_to_global( vxlist, visibleIndex )
   if a:vxlist.selector == ""
      return a:visibleIndex
   endif
   if len(a:vxlist.selected) == 0 || a:visibleIndex >= len(a:vxlist.selected)
      return -1
   endif
   return a:vxlist.selected[a:visibleIndex]
endfunc

" Set the content of the popup list to the items that match the selector.
function! s:popup_list_update_content( vxpopup_list )
   let vxlist = a:vxpopup_list
   if type(vxlist) != v:t_dict
      return
   endif
   let items = []
   let selected = []
   let select = vxlist.selector
   if select == ""
      let vxlist.selected = selected
      call popup_settext( vxlist.windowid, vxlist.content )
   else
      let idx = 0
      for it in vxlist.content
         if stridx( it, select ) >= 0
            call add( items, it )
            call add( selected, idx )
         endif
         let idx += 1
      endfor
      let vxlist.selected = selected
      call popup_settext( vxlist.windowid, items )
   endif
endfunc

" Get the vxpopup_list variable form the master popup window.
function! s:filter_get_parent_list( fltwinid )
   let vxfilter = getwinvar( a:fltwinid, "vxpopup_filter" )
   if type( vxfilter ) != v:t_dict
      return 0
   endif
   let vxlist = getwinvar( vxfilter.parent, "vxpopup_list" )
   if type( vxlist ) != v:t_dict
      return 0
   endif
   return vxlist
endfunc

function! s:filter_append_text( fltwinid, key )
   if a:key < " "
      return v:false
   endif
   let vxlist = s:filter_get_parent_list( a:fltwinid )
   if type( vxlist ) != v:t_dict
      return v:false
   endif
   let vxlist.selector .= a:key
   call popup_settext( a:fltwinid, vxlist.selector )
   call s:popup_list_update_content( vxlist )
   call s:filter_update_position( a:fltwinid, vxlist.windowid )
   return v:true
endfunc

function! s:filter_remove_text( fltwinid )
   let vxlist = s:filter_get_parent_list( a:fltwinid )
   if type( vxlist ) != v:t_dict
      return
   endif
   if strchars(vxlist.selector) > 0
      let vxlist.selector = strcharpart( vxlist.selector, 0, strchars(vxlist.selector) - 1 )
      call popup_settext( a:fltwinid, vxlist.selector )
      call s:popup_list_update_content( vxlist )
      call s:filter_update_position( a:fltwinid, vxlist.windowid )
   endif
endfunc

function! s:filter_forward_key_to_parent( fltwinid, key )
   let vxlist = s:filter_get_parent_list( a:fltwinid )
   if type( vxlist ) != v:t_dict
      return
   endif
   let options = popup_getoptions( vxlist.windowid )
   if type( options.filter ) == v:t_func
      let F = options.filter
      call F( vxlist.windowid, a:key )

      " close the filter if the parent closes
      let vxlist = s:filter_get_parent_list( a:fltwinid )
      if type( vxlist ) != v:t_dict
         call popup_close( a:fltwinid )
      endif
   endif
endfunc

function! s:filter_update_position( fltwinid, lstwinid )
   let basepos = popup_getpos( a:lstwinid )
   let baseopts = popup_getoptions( a:lstwinid )
   call popup_move( a:fltwinid, #{ 
            \ line: basepos.line + basepos.height - 1,
            \ col: basepos.col + 2 ,
            \ height: 1,
            \ width: basepos.width > 32 ? 28 : basepos.width - 4,
            \ maxwidth: basepos.width - 4,
            \ minwidth: basepos.width > 16 ? 12 : basepos.width - 4,
            \ wrap: 0,
            \ zindex: baseopts.zindex + 1
            \ })
endfunc

let s:filter_keymap = {
         \ "\<esc>" : { win -> popup_close( win ) },
         \ "\<tab>" : { win -> popup_close( win ) },
         \ "\<backspace>" : { win -> s:filter_remove_text( win ) },
         \ "\<cr>" : { win -> s:filter_forward_key_to_parent( win, "\<cr>" ) }
         \ }

function! s:popup_filter( lstwinid )
   let basepos = popup_getpos( a:lstwinid )
   let baseopts = popup_getoptions( a:lstwinid )
   let vxlist = getwinvar( a:lstwinid, "vxpopup_list" )
   let content = type(vxlist) == v:t_dict ? vxlist.selector : ""
   let keymaps = [s:filter_keymap, { win, key -> s:filter_append_text( win, key ) }]
   let fltid = popup_create( content, #{
            \ filter:  { win, key -> vimuiex#vxpopup#key_filter( win, key, keymaps ) },
            \ line: basepos.line + basepos.height - 1,
            \ col: basepos.col + 2 ,
            \ height: 1,
            \ width: basepos.width > 32 ? 28 : basepos.width - 4,
            \ maxwidth: basepos.width - 4,
            \ minwidth: basepos.width > 16 ? 12 : basepos.width - 4,
            \ wrap: 0,
            \ zindex: baseopts.zindex + 1
            \ } )
   call setwinvar( fltid, "vxpopup_filter", #{ parent: a:lstwinid } )
endfunc
