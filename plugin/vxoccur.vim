
let g:loadedPlug = get(g:, 'loadedPlug', {})
if get(g:loadedPlug, 'vxoccur', 0)
   finish
endif
let g:loadedPlug.vxoccur = -1

" <id="vimuiex#vxoccur" require="popuplist||python&&(!gui_running||python_screen)">

function! s:Check(dict, path, setting, default)
   let val = a:dict
   for p in a:path 
      let val[p] = get(val, p, {})
      let val = val[p]
   endfor
   let val[a:setting] = get(val, a:setting, a:default)
   return val[a:setting]
endfunc

let g:plug_vxoccur = get(g:, 'plug_vxoccur', {})

call s:Check(g:plug_vxoccur, [], 'routine_def', {})
call s:Check(g:plug_vxoccur, [], 'taks_words', ['COMBAK', 'TODO', 'FIXME', 'XXX'])
call s:Check(g:plug_vxoccur, [], 'hist_size', 10)
call s:Check(g:plug_vxoccur, [], 'match_limit', 1000)
" this file sets the project root when searching with -p
call s:Check(g:plug_vxoccur, [], 'project_file', '.vimproject')
" grep mode: 0 - vimgrep, 1 - grep (-r), 2 - find - xargs - grep
call s:Check(g:plug_vxoccur, [], 'grep_mode', 0)
" variables used by grep.vim
call s:Check(g:, [], 'Grep_Path', 'grep')
call s:Check(g:, [], 'Grep_Find_Path', 'find')
call s:Check(g:, [], 'Grep_Xargs_Path', 'xargs')

let vxoccur_routine_def = g:plug_vxoccur.routine_def
let vxoccur_task_words = g:plug_vxoccur.taks_words
let vxoccur_hist_size = g:plug_vxoccur.hist_size
let vxoccur_match_limit = g:plug_vxoccur.match_limit
let vxoccur_project_file = g:plug_vxoccur.project_file
let vxoccur_grep_mode = g:plug_vxoccur.grep_mode

command VxOccur call vimuiex#vxoccur#VxOccur()
command VxOccurCurrent call vimuiex#vxoccur#VxOccurCurrent()
command VxOccurRoutines call vimuiex#vxoccur#VxOccurRoutines()
command VxOccurTags call vimuiex#vxoccur#VxOccurTags()
command VxSourceTasks call vimuiex#vxoccur#VxSourceTasks()
command VxOccurHist call vimuiex#vxoccur#VxShowLastCapture(v:count)
command VxOccurSelectHist call vimuiex#vxoccur#VxSelectOccurHist()
command VxCNext call vimuiex#vxoccur#VxCNext(1)
command VxCPrev call vimuiex#vxoccur#VxCNext(-1)

function! s:F_vx_occur_map_plug_(vxcmd)
   silent exec 'nmap <unique> <Plug>' . a:vxcmd . ' :' . a:vxcmd . '<cr>'
   "silent exec 'imap <unique> <Plug>' . a:vxcmd . ' <Esc>:' . a:vxcmd . '<cr>'
   "silent exec 'vmap <unique> <Plug>' . a:vxcmd . ' :<c-u>' . a:vxcmd . '<cr>'
endfunc
call s:F_vx_occur_map_plug_('VxOccurCurrent')
call s:F_vx_occur_map_plug_('VxOccurRoutines')
call s:F_vx_occur_map_plug_('VxOccurTags')
call s:F_vx_occur_map_plug_('VxSourceTasks')
call s:F_vx_occur_map_plug_('VxCNext')
call s:F_vx_occur_map_plug_('VxCPrev')
call s:F_vx_occur_map_plug_('VxOccurSelectHist')
delfunction s:F_vx_occur_map_plug_

nmap <unique> <Plug>VxOccurHist :<c-u>VxOccurHist<cr>
"imap <unique> <Plug>VxOccurHist <Esc>:<c-u>VxOccurHist<cr>
"vmap <unique> <Plug>VxOccurHist :<c-u>VxOccurHist<cr>
nmap <unique> <Plug>VxOccurRegex :<c-u>VxOccur<cr>
"imap <unique> <Plug>VxOccurRegex <Esc>:<c-u>VxOccur<cr>
"vmap <unique> <Plug>VxOccurRegex :<c-u>VxOccur<cr>

let g:loadedPlug.vxoccur = 1
