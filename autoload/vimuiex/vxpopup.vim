" vim:set fileencoding=utf-8 sw=3 ts=3 et
" vxpopup.vim - Utilities for working with (filtered lists in) popup windows
"
" Author: Marko Mahnič
" Created: September 2019
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.

" A generic handler for popup window filters with actions defined in a list of
" dictionaries.
" The parameter keymaps is a list of dictionaries of <key, function> pairs
" where the function accepts the parameter winid as in filter option of
" popup_create.  The function element can be of type string or funcref.
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
   for km in a:keymaps
      if has_key( km, a:key )
         let FilterFunc = km[a:key] 
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

function! vimuiex#vxpopup#select_line( winid, line )
   call win_execute( a:winid, ":" . a:line )
endfunc

function! vimuiex#vxpopup#get_current_line( winid )
   return line( '.', a:winid )
endfunc

let s:list_keymap = {
         \ 'j': { win -> vimuiex#vxpopup#down( win ) },
         \ 'k': { win -> vimuiex#vxpopup#up( win ) },
         \ "\<esc>" : { win -> popup_close( win ) }
         \ }

function! vimuiex#vxpopup#popup_list( items, options )
   let current = 1
   let keymaps = [s:list_keymap]
   if has_key( a:options, "vxcurrent" )
      let current = a:options.vxcurrent
      unlet a:options.vxcurrent
      if type(current) != v:t_number
         let current = 1
      endif
   endif
   if has_key( a:options, "vxkeymap" )
      let keymaps = a:options.vxkeymap + keymaps
      unlet a:options.vxkeymap
   endif
   let a:options.filter = { win, key -> vimuiex#vxpopup#key_filter( win, key, keymaps ) }
   let a:options.cursorline = 1
   let winid = popup_dialog( a:items, a:options )
   if current > 1
      call vimuiex#vxpopup#select_line( winid, current )
   endif
   return winid
endfunc
