" vim: set fileencoding=utf-8 sw=3 ts=8 et
" vxdired.vim - file browsing utilities
"
" Author: Marko Mahnič
" Created: June 2009
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.
"
" (requires python; works only in terminal; using curses)

if vxlib#plugin#StopLoading('#au#vimuiex#vxdired')
   finish
endif

" =========================================================================== 
" Local Initialization - on autoload
" =========================================================================== 
if ! has('popuplist')
   call vxlib#python#prepare()
endif
exec vxlib#plugin#MakeSID()
" =========================================================================== 

let s:lastdir = ''

function! s:GetRecentDirList_cb()
   return join(g:VxPluginVar.vxrecentfile_dirs, "\n")
endfunc

function! s:OpenFile_cb(filename, winmode)
   call vxlib#cmd#Edit(a:filename, a:winmode)
   let s:lastdir = fnamemodify(a:filename, ':p:h')
   return 'q'
endfunc

function! s:OpenMarkedFiles_cb(curdir, marked, selected, winmode)
   if len(a:marked) < 1
      return s:OpenFile_cb(a:curdir . '/' . a:selected, a:winmode)
   endif
   only
   let first = 1
   for fname in a:marked
      call s:OpenFile_cb(a:curdir . '/' . fname, first ? '' : a:winmode)
      let first = 0
   endfor
   let s:lastdir = a:curdir
   return 'q'
endfunc

function! s:NewFile_cb(curdir)
   let cwd = getcwd()
   redraw!
   echo a:curdir
   try
      " let hinp = vxlib#hist#GetHistory('input')
      exec 'chdir ' . a:curdir
      let newfn = input('Edit file:', '', 'file')
      " call vxlib#hist#SetHistory('input', l:hinp) " restore
   finally
      exec 'chdir ' . cwd
   endtry
   if empty(newfn) | return '' | endif
   try
      exec 'edit ' . fnameescape(a:curdir . '/' . newfn)
   catch /.*/
      return ''
   endtry
   return 'q'
endfunc

" vxdired initial directory: respect browsedir setting if available
function! s:GetStartupDir()
   try
      let brd = &browsedir
   catch /.*/
      let brd = 'buffer'
   endtry
   if brd == 'buffer' || s:lastdir == ''
      let sdir = fnamemodify(bufname('%'), ':p:h') 
   elseif brd == 'last'
      let sdir = s:lastdir
   else 
      let sdir = getcwd()
   endif
   return sdir
endfunc

function! s:LsSplit(val)
   let expr = '^\(\S\+\)\s\+\(\S\+\)\s\+\(\S\+\)\s\+\(\S\+\)\s\+\(\S\+\)\s\+\(\S\+\)\s\+\(\S\+\)\s\+\(.*$\)'
   let parts = matchlist(a:val, expr)
   let rv = {
            \ 'flags': parts[1],
            \ 'sth' : parts[2],
            \ 'user' : parts[3],
            \ 'group' : parts[4],
            \ 'size' : printf('%5s', parts[5]),
            \ 'date' : parts[6],
            \ 'time' : parts[7],
            \ 'filename' : parts[8],
            \ 'directory' : (parts[1][0] == 'd'),
            \ 'symlink' : (parts[1][0] == 'l')
            \ }
   return rv
endfunc

function! s:PyLsExec(dir)
   call vxlib#python#prepare()
   let cmd = "py import vxlib.vimio; vxlib.vimio.listdir('''" . a:dir . "''')"
   let files = vxlib#cmd#Capture(cmd, 1)
   return files
endfunc

function! s:SysLsExec(dir)
   let cmd = '!ls -haln --time-style long-iso --group-directories-first ' . a:dir
   if has('gui_running')
      let files = vxlib#cmd#Capture(cmd, 1)
   else
      let files = vxlib#cmd#CaptureShell(cmd)
   endif
   return files[2:]
endfunc

if has('python')
   " let s:LsExec = function("s:PyLsExec") " TODO: problems with Python installation(version)
   let s:LsExec = function("s:SysLsExec")
else
   let s:LsExec = function("s:SysLsExec")
endif

function! s:LsRealFilename(dir, lsSplit)
   let sep = '/'
   let fname = a:lsSplit.filename
   if a:lsSplit.symlink
      let fp = split(fname, '\s\+->\s\+')
      if len(fp) == 2
         if fp[1][0] == sep
            return fp[1]
         else
            return a:dir . sep . fp[1]
         endif
      endif
   endif
   if fname == '.'
      return a:dir
   elseif fname == '..'
      return fnamemodify(a:dir, ':p:h:h')
   endif
   return a:dir . sep . a:lsSplit.filename
endfunc

" 'done:go-up' and 'accept'(..) behave differently on symlinked directories.
" 'done:go-up' will move back in history
" 'accept'(..) will move to the parent of the current directory; if the newly
"              entered directory is in history, the history will be truncated
"              at that point.
function! s:SimplePosixBrowse(startDir, xopts)
   let dir = a:startDir
   let opts = {
            \ 'keymap': { 'normal': {
            \       '<backspace>': 'done:go-up', '*': 'done:use-filter', 'e': 'done:input-filename'
            \   }},
            \ 'mode': 'normal'
            \ }
   for k in keys(a:xopts)
      if k[0] != '_'
         let opts[k] = a:xopts[k]
      endif
   endfor
   " repeat: set to 1 by 'done:use-filter' so that browsing will be repeated after this function exits
   let repeat = 0
   let dirstack = []    " list of (directory, current)
   let nametofind = ''  " name to highlight when moving up to a dir that is not in history
   while 1
      let files = s:LsExec(dir)
      let disp = []
      let index = (nametofind == '') ? 0 : -1
      for fname in files
         let pls = s:LsSplit(fname)
         if pls.directory
            let flags = '+ ' . pls.flags
         else
            let flags = '  ' . pls.flags
         endif
         call add(disp,  join([flags, pls.date, pls.time, pls.size, pls.filename], ' '))
         if index < 0 && pls.filename == nametofind
            let index = len(disp) - 1
         endif
      endfor

      if nametofind != ''
         let opts.current = index
      endif
      let rv = popuplist(disp, "File Browser: " . dir, opts)
      if rv.status == 'done:go-up'
         if len(dirstack) < 1
            let nametofind = fnamemodify(dir, ':t')
            let dir = fnamemodify(dir, ':p:h:h') " parent directory
         else
            let dirinfo = remove(dirstack, -1) " directory in history
            let dir = dirinfo[0]
            let nametofind = ''
            let opts.current = dirinfo[1]
         endif
         let opts.mode = rv.mode
      elseif rv.status == 'done:use-filter'
         let a:xopts.mode = rv.mode
         let a:xopts._browse_mode = 'filter'
         let a:xopts._dir = dir
         let repeat = 1
         break
      elseif rv.status == 'done:input-filename'
         let wrkdir = getcwd()
         exec "cd " . dir
         let fn = input('From: ' . dir . "\nOpen: ", '', 'file')
         exec "cd " . wrkdir
         let fn = matchstr(fn, '^\s*\zs.*$')
         if fn == ''
            redraw
         else
            if fn[0] == '/'
               exec 'edit ' . fn
            else
               exec 'edit ' . dir . '/' . fn
            endif
            break
         endif
      elseif rv.status == 'accept'
         if rv.current > 0 && rv.current < len(files)
            let pls = s:LsSplit(files[rv.current])
            let pls.realfilename = s:LsRealFilename(dir, pls)
            if pls.symlink
               let pls.directory = getftype(pls.realfilename) == 'dir'
            endif
            if pls.directory
               let opts.current = 0
               let nametofind = ''
               if pls.filename == '..'
                  let nametofind = fnamemodify(dir, ':t')
                  let dir = pls.realfilename
                  let idx = len(dirstack) - 1
                  while idx >= 0
                     if dirstack[idx][0] == dir
                        break
                     endif
                     let idx = idx - 1
                  endwhile
                  if idx >= 0
                     let nametofind = ''
                     let opts.current = dirstack[idx][1]
                     call remove(dirstack, idx, len(dirstack)-1)
                  endif
               elseif pls.filename != '.'
                  call add(dirstack, [dir, rv.current])
                  let dir = pls.realfilename
                  let nametofind = '..'
               endif
            else
               call s:OpenFile_cb(pls.realfilename, '')
               break
            endif
         endif
         let opts.mode = rv.mode
      else
         break
      endif
   endwhile
   return repeat
endfunc

function! s:FindSplit(val)
   let expr = '^\(\S\+\)\s\+\(.*$\)'
   let parts = matchlist(a:val, expr)
   if len(parts) < 3
      let rv = {
               \ 'flags': '', 'filename' : val,
               \ 'directory' : 0, 'symlink' : 0
               \ }
   else
      let rv = {
               \ 'flags': parts[1],
               \ 'filename' : parts[2],
               \ 'directory' : (parts[1][0] == 'd'),
               \ 'symlink' : (parts[1][0] == 'l')
               \ }
   return rv
endfunc

function! s:FindModify(val)
   let pls = s:FindSplit(a:val)
   if pls.directory
      let flags = '+ '
   else
      let flags = '  '
   endif
   return join([flags, pls.filename], ' ')
endfunc

function! s:FindExec(dir)
   let skipdirs = split(g:VxFileFilter_skipDirs, ',')
   call map(skipdirs, '"-name \"" . v:val . "\""')
   let skipfiles = split(g:VxFileFilter_skipFiles, ',')
   call map(skipfiles, '"-name \"" . v:val . "\""')

   let cmd = '!' . g:Grep_Find_Path . ' "' . a:dir . '" -maxdepth ' . g:VxFileFilter_treeDepth
   let cmd = cmd . ' -a \( '
   let cmd = cmd . '  \( -type d -a \( ' . join(skipdirs, ' -o ') . ' \) '
   let cmd = cmd . '   -o \( \! -type d \) -a \( ' . join(skipfiles, ' -o ') . ' \) '
   let cmd = cmd . '  \) -prune -o -printf "\%y \%P\n" '
   let cmd = cmd . ' \)'

   if has('gui_running')
      let files = vxlib#cmd#Capture(cmd, 1)
   else
      let files = vxlib#cmd#CaptureShell(cmd)
   endif
   return files[1:]
endfunc

function! s:SimplePosixFilter(startDir, xopts)
   let dir = a:startDir
   let opts = {
            \ 'keymap': { 'normal': { '<backspace>': 'done:go-up', '*': 'done:use-browse' }},
            \ 'mode': 'filter'
            \ }
   for k in keys(a:xopts)
      if k[0] != '_'
         let opts[k] = a:xopts[k]
      endif
   endfor
   " repeat: set to 1 by 'done:use-browse' so that browsing will be repeated after this function exits
   let repeat = 0
   while 1
      let files = s:FindExec(dir)
      let disp = copy(files)
      call map(disp, 's:FindModify(v:val)')

      let rv = popuplist(disp, "File Filter: " . dir, opts)
      if rv.status == 'done:go-up'
         let dir = fnamemodify(dir, ':p:h:h') " parent directory
         let opts.mode = rv.mode
      elseif rv.status == 'done:use-browse'
         let a:xopts.mode = rv.mode
         let a:xopts._browse_mode = 'browse'
         let a:xopts._dir = dir
         let repeat = 1
         break
      elseif rv.status == 'accept'
         if rv.current > 0 && rv.current < len(files)
            let pls = s:FindSplit(files[rv.current])
            if pls.directory
               let dir = dir . '/' . pls.filename
            else
               call s:OpenFile_cb(dir . '/' . pls.filename, '')
               break
            endif
         endif
         let opts.mode = rv.mode
      else
         break
      endif
   endwhile
   return repeat
endfunc

" The file browser uses an internal command 'list:dired-select' to open
" selected items. If the selected item is a file, the internal command will
" use the expression defined in FBrowse.callbackEditFile to construct
" a callback and evaluate it. The internal command can accept one string
" parameter (without quotes) which will be passed to vxlib#cmd#Edit.
" @param mode:
"     'browse' - show current directory, normal operation
"     'filter' - show directory tree, filter mode
function! vimuiex#vxdired#VxFileBrowser(mode)
   if has('popuplist')
      let opts = { '_browse_mode': a:mode, '_dir': s:GetStartupDir() }
      let repeat = 1
      while repeat
         if opts._browse_mode == 'browse'
            let repeat = s:SimplePosixBrowse(opts._dir, opts)
         elseif opts._browse_mode == 'filter'
            let repeat = s:SimplePosixFilter(opts._dir, opts)
         else
            let repeat = 0
         endif
      endwhile
      return
   endif
   exec 'python def SNR(s): return s.replace("$SNR$", "' . s:SNR . '")'

python << EOF
import vim
import vimuiex.dired as dired
import vimuiex.popuplist as popuplist
FBrowse = dired.CFileBrowser(optid="VxFileBrowser")
FBrowse.exprRecentDirList = SNR("$SNR$GetRecentDirList_cb()")
FBrowse.callbackEditFile = SNR("$SNR$OpenMarkedFiles_cb({{pwd}}, {{S}}, {{s}}, {{p}})")
# default command
FBrowse.keymapNorm.setKey(r"\<cr>", "list:dired-select") # also mapped in python
FBrowse.keymapNorm.setKey(r"\<c-cr>", "list:dired-select t")
# additional commands
FBrowse.keymapNorm.setKey(r"e", SNR("vim:$SNR$NewFile_cb({{pwd}})"))
FBrowse.keymapNorm.setKey(r"gt", "list:dired-select t")
FBrowse.keymapNorm.setKey(r"gs", "list:dired-select s")
FBrowse.keymapNorm.setKey(r"gv", "list:dired-select v")
EOF
   if a:mode == 'filter'
      exec 'python FBrowse.subdirDepth=' . g:VxFileFilter_treeDepth
      exec 'python FBrowse.deepListLimit=' . g:VxFileFilter_limitCount
      exec 'python FBrowse.fileFilter.skipFiles("' . escape(g:VxFileFilter_skipFiles, '\"') . '")'
      exec 'python FBrowse.fileFilter.skipDirs("' . escape(g:VxFileFilter_skipDirs, '\"') . '")'
      exec 'python FBrowse.process(curindex=0, cwd="' . escape(s:GetStartupDir(), ' \"') . '"' .
               \ ', startmode=popuplist.CList.MODE_FILTER)'
   else
      exec 'python FBrowse.fileFilter.skipFiles("' . escape(g:VxFileBrowser_skipFiles, '\"') . '")'
      exec 'python FBrowse.fileFilter.skipDirs("' . escape(g:VxFileBrowser_skipDirs, '\"') . '")'
      exec 'python FBrowse.process(curindex=0, cwd="' . escape(s:GetStartupDir(), ' \"') . '")'
   endif
   python FBrowse=None

endfunc

" ===========================================================================
" Global Initialization - Processed by Plugin Code Generator
" ===========================================================================
finish

" <VIMPLUGIN id="vimuiex#vxdired" require="popuplist||python&&(!gui_running||python_screen)">
   call s:CheckSetting('g:VxRecentFile_nocase', !has('fname_case'))
   call s:CheckSetting('g:VxRecentDir_size', 20)
   call s:CheckSetting('g:VxFileFilter_treeDepth', 6)
   call s:CheckSetting('g:VxFileFilter_skipFiles', "'*.pyc,*.o,*.*~,*.~*,.*.swp'")
   call s:CheckSetting('g:VxFileFilter_skipDirs', "'.git,.svn,.hg'")
   call s:CheckSetting('g:VxFileFilter_limitCount', 0)
   call s:CheckSetting('g:VxFileBrowser_skipFiles', 'g:VxFileFilter_skipFiles')
   call s:CheckSetting('g:VxFileBrowser_skipDirs', "''")
   " variables used by grep.vim
   call s:CheckSetting('g:Grep_Find_Path', "'find'")

   function! s:VIMUIEX_dired_SaveHistory()
      let g:VXRECENTDIRS = join(g:VxPluginVar.vxrecentfile_dirs, "\n")
   endfunc

   function! s:VIMUIEX_dired_AutoMRU(filename) " based on tmru.vim
      if ! has_key(g:VxPluginVar, 'vxrecentfile_dirs') | return | endif
      if &buflisted && &buftype !~ 'nofile' && fnamemodify(a:filename, ':t') != ''
         let dir = fnamemodify(a:filename, ':p:h')
         let dirs = g:VxPluginVar.vxrecentfile_dirs
         let idx = index(dirs, dir, 0, g:VxRecentFile_nocase)
         if idx == -1
            let rdirs = []
            for fnm in dirs
               call add(rdirs, resolve(fnm))
            endfor
            let rfname = resolve(dir)
            let idx = index(rdirs, rfname, 0, g:VxRecentFile_nocase)
         endif
         if idx == -1 && len(dirs) >= g:VxRecentDir_size
            let idx = g:VxRecentDir_size - 1
         endif
         if idx > 0  | call remove(dirs, idx) | endif
         if idx != 0 | call insert(dirs, dir) | endif
      endif
   endf

   augroup vxdired
      autocmd!
      autocmd BufWritePost,BufReadPost  * call s:VIMUIEX_dired_AutoMRU(expand('<afile>:p'))
      autocmd VimLeavePre * call s:VIMUIEX_dired_SaveHistory()
   augroup END

   " <STARTUP>
      call s:CheckSetting('g:VXRECENTDIRS', '""')
      let g:VxPluginVar.vxrecentfile_dirs = split(g:VXRECENTDIRS, "\n")
   " </STARTUP>

   command VxFileBrowser call vimuiex#vxdired#VxFileBrowser('browse')
   command VxFileFilter call vimuiex#vxdired#VxFileBrowser('filter')
   nmap <silent><unique> <Plug>VxFileBrowser :VxFileBrowser<cr>
   imap <silent><unique> <Plug>VxFileBrowser <Esc>:VxFileBrowser<cr>
   vmap <silent><unique> <Plug>VxFileBrowser :<c-u>VxFileBrowser<cr>
   nmap <silent><unique> <Plug>VxFileFilter :VxFileFilter<cr>
   imap <silent><unique> <Plug>VxFileFilter <Esc>:VxFileFilter<cr>
   vmap <silent><unique> <Plug>VxFileFilter :<c-u>VxFileFilter<cr>

" </VIMPLUGIN>
