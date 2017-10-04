
let g:loadedPlug = get(g:, 'loadedPlug', {})
if get(g:loadedPlug, 'vxproject', 0)
   finish
endif
let g:loadedPlug.vxproject = -1

" <id="vimuiex#vxproject" require="popuplist||python&&(!gui_running||python_screen)">

function! s:Check(dict, path, setting, default)
   let val = a:dict
   for p in a:path 
      let val[p] = get(val, p, {})
      let val = val[p]
   endfor
   let val[a:setting] = get(val, a:setting, a:default)
   return val[a:setting]
endfunc

let g:plug_vxproject = get(g:, 'plug_vxproject', {})

" TODO: this should be a list of possible files/file extensions
" TODO: default name? .vimproject, .vxproject, .vxprj, .vimxprj?
call s:Check(g:plug_vxproject, [], 'project_file', '.vimproject')
call s:Check(g:plug_vxproject, [], 'project_subdir', '.vxproject')
" python or vim (maybe also: python, pyscript)
call s:Check(g:plug_vxproject, [], 'lister', 'syspython')

let g:vxproject_project_file = g:plug_vxproject.project_file
let g:vxproject_project_subdir = g:plug_vxproject.project_subdir
let g:vxproject_lister = g:plug_vxproject.lister

command VxProjectFileFilter call vimuiex#vxproject#SelectProjectFile()
nmap <silent><unique> <Plug>VxProjectFileFilter :VxProjectFileFilter<cr>

let g:loadedPlug.vxproject = 1

