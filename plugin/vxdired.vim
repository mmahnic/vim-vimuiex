if vxlib#load#IsLoaded( 'vxdired' )
   finish
endif
call vxlib#load#SetLoaded( 'vxdired', 1 )

" <id="vimuiex#vxdired" require="popuplist||python&&(!gui_running||python_screen)">

function! s:Check(dict, path, setting, default)
   let val = a:dict
   for p in a:path 
      let val[p] = get(val, p, {})
      let val = val[p]
   endfor
   let val[a:setting] = get(val, a:setting, a:default)
   return val[a:setting]
endfunc

let g:plug_vxdired = get(g:, 'plug_vxdired', {})

call s:Check(g:plug_vxdired, ['recent_file'], 'nocase', !has('fname_case'))
call s:Check(g:plug_vxdired, ['recent_dir'], 'size', 20)
call s:Check(g:plug_vxdired, ['file_filter'], 'tree_depth', 6)
call s:Check(g:plug_vxdired, ['file_filter'], 'skip_files', '*.pyc,*.o,*.*~,*.~*,.*.swp')
call s:Check(g:plug_vxdired, ['file_filter'], 'skip_dirs', '.git,.svn,.hg')
call s:Check(g:plug_vxdired, ['file_filter'], 'limit', 0)
call s:Check(g:plug_vxdired, ['file_browser'], 'skip_files', g:plug_vxdired.file_filter.skip_files)
call s:Check(g:plug_vxdired, ['file_browser'], 'skip_dirs', '')
" variables used by grep.vim
call s:Check(g:, [], 'Grep_Find_Path', 'find')

" TODO: the code in autoload should use g:plug_vxdired
let g:VxRecentFile_nocase = g:plug_vxdired.recent_file.nocase
let g:VxRecentDir_size = g:plug_vxdired.recent_dir.size
let g:VxFileFilter_treeDepth = g:plug_vxdired.file_filter.tree_depth
let g:VxFileFilter_skipFiles = g:plug_vxdired.file_filter.skip_files
let g:VxFileFilter_skipDirs = g:plug_vxdired.file_filter.skip_dirs
let g:VxFileFilter_limitCount = g:plug_vxdired.file_filter.limit
let g:VxFileBrowser_skipFiles = g:plug_vxdired.file_browser.skip_files
let g:VxFileBrowser_skipDirs = g:plug_vxdired.file_browser.skip_dirs
" let g:Grep_Find_Path = g:Grep_Find_Path

function! s:VIMUIEX_dired_SaveHistory()
   let g:VXRECENTDIRS = join(g:VxPluginVar.vxrecentfile_dirs, "\n")
endfunc

function! s:VIMUIEX_dired_RestoreHistory()
   call s:Check(g:, [], 'VXRECENTDIRS', '')
   let g:VxPluginVar.vxrecentfile_dirs = split(g:VXRECENTDIRS, "\n")
endfunc

function! s:VIMUIEX_dired_AutoMRU(filename) " based on tmru.vim
   if ! has_key(g:VxPluginVar, 'vxrecentfile_dirs') | return | endif
   if &buflisted && &buftype !~ 'nofile' && fnamemodify(a:filename, ':t') != ''
      let dir = fnamemodify(a:filename, ':p:h')
      let dirs = g:VxPluginVar.vxrecentfile_dirs
      let idx = index(dirs, dir, 0, g:VxRecentFile_nocase)
      if idx == -1
         if 1
            let rdirs = dirs
         else
            " FIXME: resolve takes too much time if a network fs is not available
            let rdirs = []
            for fnm in dirs
               call add(rdirs, resolve(fnm))
            endfor
         endif
         if 1
            " FIXME: Ignore link conversion because of bad network speed
            let rfname = dir
         else
            " let rfname = resolve(dir)
         endif
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
augroup vxdired_startup
   autocmd VimEnter * call s:VIMUIEX_dired_RestoreHistory()
            \ | autocmd! vxdired_startup
augroup END

command VxFileBrowser call vimuiex#vxdired#VxFileBrowser('browse')
command VxFileFilter call vimuiex#vxdired#VxFileBrowser('filter')
nmap <silent><unique> <Plug>VxFileBrowser :VxFileBrowser<cr>
imap <silent><unique> <Plug>VxFileBrowser <Esc>:VxFileBrowser<cr>
vmap <silent><unique> <Plug>VxFileBrowser :<c-u>VxFileBrowser<cr>
nmap <silent><unique> <Plug>VxFileFilter :VxFileFilter<cr>
imap <silent><unique> <Plug>VxFileFilter <Esc>:VxFileFilter<cr>
vmap <silent><unique> <Plug>VxFileFilter :<c-u>VxFileFilter<cr>

