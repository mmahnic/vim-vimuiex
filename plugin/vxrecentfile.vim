
let g:loadedPlug = get(g:, 'loadedPlug', {})
if get(g:loadedPlug, 'vxrecentfile', 0)
   finish
endif
let g:loadedPlug.vxrecentfile = -1

" <id="vimuiex#vxrecentfile" require="popuplist||python&&(!gui_running||python_screen)">

function! s:Check(dict, path, setting, default)
   let val = a:dict
   for p in a:path
      let val[p] = get(val, p, {})
      let val = val[p]
   endfor
   let val[a:setting] = get(val, a:setting, a:default)
   return val[a:setting]
endfunc

let g:plug_vxrecentfile = get(g:, 'plug_vxrecentfile', {})

" TODO: move these settings to plug_vxrecentfile
call s:Check(g:, [], 'VxRecentFile_size', 50)
call s:Check(g:, [], 'VxRecentFile_exclude', '')
call s:Check(g:, [], 'VxRecentFile_nocase', !has('fname_case'))

function! s:VIMUIEX_recentfile_SaveHistory()
   let g:VXRECENTFILES = join(g:VxPluginVar.vxrecentfile_files, "\n")
endfunc

function! s:VIMUIEX_recentfile_RestoreHistory()
   call s:Check(g:, [], 'VXRECENTFILES', '')
   let g:VxPluginVar.vxrecentfile_files = split(g:VXRECENTFILES, "\n")
endfunc

function! s:VIMUIEX_recentfile_AutoMRU(filename) " based on tmru.vim
   if ! has_key(g:VxPluginVar, 'vxrecentfile_files') | return | endif
   if &buflisted && &buftype !~ 'nofile' && fnamemodify(a:filename, ':t') != ''
      if g:VxRecentFile_exclude != '' && a:filename =~ g:VxRecentFile_exclude
         return
      endif
      let files = g:VxPluginVar.vxrecentfile_files
      let idx = index(files, a:filename, 0, g:VxRecentFile_nocase)
      if idx == -1
         let rfiles = []
         for fnm in files
            call add(rfiles, resolve(fnm))
         endfor
         let rfname = resolve(a:filename)
         let idx = index(rfiles, rfname, 0, g:VxRecentFile_nocase)
      endif
      if idx == -1 && len(files) >= g:VxRecentFile_size
         let idx = g:VxRecentFile_size - 1
      endif
      if idx > 0  | call remove(files, idx) | endif
      if idx != 0 | call insert(files, a:filename) | endif
   endif
endf

augroup vxrecentfile
   autocmd!
   autocmd BufWritePost,BufReadPost * call s:VIMUIEX_recentfile_AutoMRU(expand('<afile>:p'))
   autocmd VimLeavePre * call s:VIMUIEX_recentfile_SaveHistory()
augroup END
augroup vxrecentfile_startup
   autocmd VimEnter * call s:VIMUIEX_recentfile_RestoreHistory()
            \ | autocmd! vxrecentfile_startup
augroup END

command VxOpenRecentFile call vimuiex#vxrecentfile#VxOpenRecentFile()
nmap <silent><unique> <Plug>VxOpenRecentFile :VxOpenRecentFile<cr>
imap <silent><unique> <Plug>VxOpenRecentFile <Esc>:VxOpenRecentFile<cr>
vmap <silent><unique> <Plug>VxOpenRecentFile :<c-u>VxOpenRecentFile<cr>

let g:loadedPlug.vxrecentfile = 1
