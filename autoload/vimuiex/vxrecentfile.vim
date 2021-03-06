" vim: set fileencoding=utf-8 sw=3 ts=8 et
" vxrecentfile.vim - display a list of recent files in a popup window
"
" Author: Marko Mahnič
" Created: April 2009
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.
"
" (requires python)

if vxlib#plugin#StopLoading('#au#vimuiex#vxrecentfile')
   finish
endif

" =========================================================================== 
" Local Initialization - on autoload
" =========================================================================== 
" call vxlib#python#prepare()
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

function! vimuiex#vxrecentfile#VxOpenRecentFile()
   if has('popuplist')
      " echom strftime("%M:%S") . "VxOpenRecentFile"
      let rslt=popuplist(s:GetRecentFiles(), 'Recent Files', {'columns': 1})
      if rslt.status == 'accept'
         call s:SelectFile_cb(rslt.current, '')
      endif
   else
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

