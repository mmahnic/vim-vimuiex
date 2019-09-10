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
   for Km in a:keymaps
      if type( Km ) == v:t_func
         " TODO: the handler should tell if keymap processing should continue
         call Km( a:winid, a:key )
      elseif has_key( Km, a:key )
         let FilterFunc = Km[a:key]
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

function! vimuiex#vxpopup#get_current_line( winid )
   return line( '.', a:winid )
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

   let maxwidth = &columns - 6
   if has_key( a:options, "maxwidth" ) && a:options.maxwidth < maxwidth
      let maxwidth = a:options.maxwidth
   endif
   let a:options.maxwidth = maxwidth

   let maxheight = &lines - 6
   if has_key( a:options, "maxheight" ) && a:options.maxheight < maxheight
      let maxheight = a:options.maxheight
   endif
   let a:options.maxheight = maxheight

   let a:options.wrap = 0

   let a:options.filter = { win, key -> vimuiex#vxpopup#key_filter( win, key, keymaps ) }
   let a:options.cursorline = 1
   let winid = popup_dialog( a:items, a:options )
   if current > 1
      call vimuiex#vxpopup#select_line( winid, current )
   endif
   call setwinvar( winid, "vxpopup_list", #{ filter: "" } )
   return winid
endfunc

let s:filter_keymap = {
         \ "\<esc>" : { win -> popup_close( win ) },
         \ "\<backspace>" : { win -> s:filter_remove_text( win ) }
         \ }

function! s:filter_get_parent_list( winid )
   let vxfilter = getwinvar( a:winid, "vxpopup_filter" )
   if type( vxfilter ) != v:t_dict
      return 0
   endif
   let vxlist = getwinvar( vxfilter.parent, "vxpopup_list" )
   if type( vxlist ) != v:t_dict
      return 0
   endif
   return vxlist
endfunc

function! s:filter_append_text( winid, key )
   if a:key < " "
      return
   endif
   let vxlist = s:filter_get_parent_list( a:winid )
   if type( vxlist ) != v:t_dict
      return
   endif
   let vxlist.filter .= a:key
   call popup_settext( a:winid, vxlist.filter )
endfunc

function! s:filter_remove_text( winid )
   let vxlist = s:filter_get_parent_list( a:winid )
   if type( vxlist ) != v:t_dict
      return
   endif
   if strchars(vxlist.filter) > 0
      let vxlist.filter = strcharpart( vxlist.filter, 0, strchars(vxlist.filter) - 1 )
      call popup_settext( a:winid, vxlist.filter )
   endif
endfunc

function! s:popup_filter( winid )
   let basepos = popup_getpos( a:winid )
   let baseopts = popup_getoptions( a:winid )
   let vxlist = getwinvar( a:winid, "vxpopup_list" )
   let content = type(vxlist) == v:t_dict ? vxlist.filter : ""
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
   call setwinvar( fltid, "vxpopup_filter", #{ parent: a:winid } )
endfunc
