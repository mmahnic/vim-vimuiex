" vim:set fileencoding=utf-8 sw=3 ts=3 et
" vxtabs.vim - display a list of tabs in a popup window
"
" Author: Marko Mahnič
" Created: April 2011
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.
"
" (requires python)

if vxlib#plugin#StopLoading('#au#vimuiex#vxtabs')
  finish
endif

" =========================================================================== 
" Local Initialization - on autoload
" =========================================================================== 
" call vxlib#python#prepare()
exec vxlib#plugin#MakeSID()
let g:_VxPopupListPosDefault['VxTabSelect'] = 'position=311'
" =========================================================================== 

function! s:GetTabList()
   let lstabs = vxlib#cmd#Capture('tabs', 1)
   let tablist = []
   let itab = {}
   for line in lstabs
      if line =~ '^\s\+'
         let fn = matchstr(line, '^\s\+\zs.*$')
         call add(itab.files, fnamemodify(fn, ':t'))
      elseif line =~ '^>\s\+'
         let fn = matchstr(line, '^>\s\+\zs.*$')
         call insert(itab.files, fnamemodify(fn, ':t'))
      else
         let itab = { 'title': line, 'files': [] }
         call add(tablist, itab)
      endif
   endfor
   let result = []
   for itab in tablist
      let title = printf("%s\t%s", itab.title, join(itab.files, ', '))
      call add(result, title)
   endfor
   return result
endfunc

function! s:SelectItem_tabs(index)
   exec 'tabnext ' . (a:index + 1)
endfunc

function! vimuiex#vxtabs#VxTabSelect()
   if has('popuplist')
      " TODO: position below the tabs -> limits (0, 1, ...), pos (00 or 80)
      let pos = '01'  " don't cover the tabs
      if has('gui_running')
         let pos = '00'
      endif
      let rslt = popuplist(s:GetTabList(), 'Go to tab', { 'pos': pos })
      if rslt.status == 'accept'
         let itab = rslt.current
         exec 'tabnext ' . (itab + 1)
      endif
   else
      call vimuiex#vxlist#VxPopup(s:GetTabList(), 'Go to tab', {
               \ 'optid': 'VxTabSelect',
               \ 'callback': s:SNR . 'SelectItem_tabs({{i}})'
               \ })
   endif
endfunc

" =========================================================================== 
" Global Initialization - Processed by Plugin Code Generator
" =========================================================================== 
finish

" <VIMPLUGIN id="vimuiex#vxtabs" require="popuplist||python&&(!gui_running||python_screen)">
   command VxTabSelect call vimuiex#vxtabs#VxTabSelect()
" </VIMPLUGIN>
