" vim: set fileencoding=utf-8 sw=3 ts=8 et
" vxrecentfile.vim - display a list of recent files in a popup window
"
" Author: Marko Mahnič
" Created: April 2009
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.

if vxlib#load#IsLoaded( '#vimuiex#vxrecentfile' )
   finish
endif
call vxlib#load#SetLoaded( '#vimuiex#vxrecentfile', 1 )

" =========================================================================== 
" Local Initialization - on autoload
" =========================================================================== 
exec vxlib#plugin#MakeSID()
" =========================================================================== 

" -------------------------------------------------------
" Displaying the MRU list
" -------------------------------------------------------

let s:SHOWNFILES=[]
function! s:GetRecentFiles()
   " echom strftime("%M:%S") . "GetRecentFiles"
   let s:SHOWNFILES = []
   for item in g:VxPluginVar.vxrecentfile_files
      if item =~ "^//"
         " Avoid long network waits...
         call add(s:SHOWNFILES, fnamemodify(item, ':t') . "\t" . item )
      else
         call add(s:SHOWNFILES, fnamemodify(item, ':t') . "\t" . fnamemodify(item, ':p:~:h'))
      endif
   endfor
   " echom strftime("%M:%S") . "GetRecentFiles end"
   return s:SHOWNFILES
endfunc

function! s:SelectFile_cb(index, winmode)
   let filename = s:SHOWNFILES[a:index]
   let fparts = split(filename, "\t")
   if fparts[1] =~ "^//"
      let filename = fparts[1]
   else
      let filename = fparts[1] . '/' . fparts[0]
   endif
   let filename = fnamemodify(filename, ':p')

   call vxlib#cmd#Edit(filename, a:winmode)
   return 'q'
endfunc

function! s:SelectMarkedFiles_cb(marked, index, winmode)
   if len(a:marked) < 1
      return s:SelectFile_cb(a:index, a:winmode)
   endif
   only
   let first = 1
   for idx in a:marked
      call s:SelectFile_cb(idx, first ? '' : a:winmode)
      let first = 0
   endfor
   return 'q'
endfunc

function! s:OpenRecenFiles_select_file( winid )
   let chooser = vxlib#popup#GetState( a:winid )
   let itemIndex = chooser.GetCurrentIndex()
   call s:SelectFile_cb( itemIndex, '' )
   call chooser.Close()
endfunc

let s:recent_keymap = {
         \ "\<cr>" : { win -> s:OpenRecenFiles_select_file( win ) }
         \ }

function! s:OpenRecentFile_chooser()
   let chooser = vxlib#chooser#Create( s:GetRecentFiles(), #{
            \ title: "Recent Files",
            \ vx: #{ keymaps: [s:recent_keymap], columns: 2 }
            \ } )
   let winid = chooser.Show()
endfunc

" OLD: Uses the C popuplist function.
function! s:OpenRecentFile_popuplist()
   if has('popuplist')
      " echom strftime("%M:%S") . "VxOpenRecentFile"
      let rslt=popuplist(s:GetRecentFiles(), 'Recent Files', {'columns': 1})
      if rslt.status == 'accept'
         call s:SelectFile_cb(rslt.current, '')
      endif
endfunc

" OLD: Uses the Python popuplist.
function! s:OpenRecentFile_vxpopup()
   if has('python') && !has('gui')
      call vimuiex#vxlist#VxPopup(s:GetRecentFiles(), 'Recent files', {
         \ 'optid': 'VxOpenRecentFile',
         \ 'callback': s:SNR . 'SelectMarkedFiles_cb({{M}}, {{i}}, '''')', 
         \ 'columns': 1,
         \ 'keymap': [
            \ ['gs', 'vim:' . s:SNR . 'SelectMarkedFiles_cb({{M}}, {{i}}, ''s'')'],
            \ ['gv', 'vim:' . s:SNR . 'SelectMarkedFiles_cb({{M}}, {{i}}, ''v'')'],
            \ ['gt', 'vim:' . s:SNR . 'SelectMarkedFiles_cb({{M}}, {{i}}, ''t'')'],
            \ ['\<s-cr>', 'vim:' . s:SNR . 'SelectMarkedFiles_cb({{M}}, {{i}}, ''t'')'],
         \  ]
         \ })
   endif
   
endfunc

function! vimuiex#vxrecentfile#VxOpenRecentFile()
   if ( v:version >= 801 )
      call s:OpenRecentFile_chooser()
      return
   endif
   if has('popuplist')
      call s:OpenRecentFile_popuplist()
      return
   endif
   if has('python') && !has('gui')
      call s:OpenRecentFile_vxpopup()
      return
   endif
   echom "A popup list required by vxrecentfile is not available."
endfunc
