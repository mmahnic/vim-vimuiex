" vim:set fileencoding=utf-8 sw=3 ts=3 et
" vxproject.vim - load settings for each buffer from a project file
"
" Author: Marko Mahnič
" Created: October 2012
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.

if vxlib#plugin#StopLoading('#au#vimuiex#vxproject')
"   finish
endif

" =========================================================================== 
" Local Initialization - on autoload
" =========================================================================== 
exec vxlib#plugin#MakeSID()
" =========================================================================== 

let s:Projects = {}

function! s:Strip(input_string)
   return substitute(a:input_string, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction

function! s:StripSection(input_string)
   return substitute(a:input_string, '^\%(\[\|\s\)*\(.\{-}\)\%(\s\|\]\)*$', '\1', '')
endfunction

function! s:RStrip(input_string)
   return substitute(a:input_string, '^\(.\{-}\)\s*$', '\1', '')
endfunction

function! s:ExpandReferences(project, section)
endfunc

function! s:FindProjectFile(startdir)
   if g:vxproject_project_file == "" 
      return ""
   endif
   let cwd = fnamemodify(a:startdir, ':p')
   let prevdir = ""
   while cwd != prevdir
      let fn = cwd . '/' . g:vxproject_project_file
      if filereadable(fn)
         return fn
      endif
      let prevdir = cwd
      let cwd = fnamemodify(cwd, ':h')
   endwhile
   return ""
endfunc

" Sections:
"   - sources     list of source files / filemasks
"   - headers     list of header files / filemasks
"   - binaries    list of binary files / filemasks
"   - resources   list of resource files / filemasks
"   - others      list of other files / filemasks
"   - includes    list of projects that this project depends on
"   - subprojects list of subprojects
"   - ctags       list of files to process with ctags (or sth. else)
"                 may contain references to other sections, eg. @sources
let s:listSections = ['sources', 'headers', 'binaries', 'resources', 'others']
let s:includeSections = ['includes', 'subprojects']
let s:processSections = ['ctags']
let s:sectionAlias = { 'source': 'sources', 'header': 'headers',
         \ 'binary': 'binaries', 'resource': 'resources', 'other': 'others',
         \ 'include': 'includes', 'subproject': 'subprojects',
         \ 'tag': 'ctags', 'tags': 'ctags'
         \ }

let s:sectionParsers = {
         \ 'ctags': function(s:SNR . "ExpandReferences"),
         \ 'plug:vxoccur': function(s:SNR . "ExpandReferences")
         \ }

function! s:GetSection(project, section)
   if has_key(s:sectionAlias, a:section)
      let section = s:sectionAlias[a:section]
   else
      let section = a:section
   endif
   return a:project[section]
endfunc

" [section]
" [.subsection]
function! s:LoadProject(fname)
   let project = { 'project-file': a:fname }
   let lines = readfile(a:fname)

   let header = 1
   let section = ""
   let seclines = []
   for ln in lines
      if ln =~ '^\s*$'
         continue
      endif
      if header == 1 
         if ln !~ '^#'
            let header = 0
         else
            if ln =~ '^#\s*@title\s*:'
               let ln = substitute(ln, '^#\s*@title\s*:\s*\(.\{-}\)\s*$', '\1', '')
               let project['title'] = ln
            endif
            continue
         endif
      endif
      if ln =~ '^#'
         continue
      endif
      if ln =~ '^[' && ln !~ '^[\.]'
         if section != ""
            let project[section] = seclines
         endif
         let seclines = []
         let section = s:StripSection(ln)
         if has_key(s:sectionAlias, section)
            let section = s:sectionAlias[section]
         endif
         continue
      endif
      call add(seclines, s:RStrip(ln))
   endfor
   if section != ""
      let project[section] = seclines
      let seclines = []
   endif
   return project
endfunc

" Get the project settings for buffer
function! vimuiex#vxproject#GetBufferProject(bufnr)
   let prj = getbufvar(a:bufnr, 'vxproject')
   if type(prj) == type({})
      return prj
   endif
   unlet prj
   let prjfile = s:FindProjectFile(fnamemodify(bufname(a:bufnr), ':p:h'))
   if prjfile == ""
      let prj = {}
   else
      let prjkey = simplify(prjfile) " alternative: resolve()
      if has_key(s:Projects, prjkey)
         " echom "FOUND"
         let prj = s:Projects[prjkey]
      else
         " echom "LOADING"
         let prj = s:LoadProject(prjfile)
         let s:Projects[prjkey] = prj
      endif
   endif
   call setbufvar(a:bufnr, 'vxproject', prj)
   return prj
endfunc

function! s:FilepathMatch(fullpath, mask)
   " try to convert a glob() pattern into a regex
   let m = a:mask
   " let m = substitute(m, '\M.',       '\\.', 'g')
   let m = substitute(m, '\M**/*\{}', '\\.\\{-}', 'g')
   let m = substitute(m, '\M***\{}',  '\\.\\{-}', 'g')
   let m = substitute(m, '\M*',       '\\[^/]\\{-}', 'g')
   let m = substitute(m, '\M?',       '\\[^/]', 'g')
   let m = '\M^' . m . '$'
   " echom '-path: ' . a:fullpath
   " echom ' mask: ' . a:mask
   " echom ' patt: ' . m
   " echom ' found: ' . string(match(a:fullpath, m))
   return match(a:fullpath, m) == 0
endfunc

function! s:IsFileInProject(fullpath, prj)
   let bdir = fnamemodify(a:prj['project-file'], ':h')
   for sec in s:listSections
      if !has_key(a:prj, sec)
         continue
      endif
      let masks = a:prj[sec]
      for m in masks
         if m =~ '^/'
            let found = s:FilenpathMatch(a:fullpath, m)
         else
            let found = s:FilepathMatch(a:fullpath, bdir . '/' . m)
         endif
         if found
            " TODO: if belongs to a subproject, return 2
            return 1
         endif
      endfor
   endfor
   return 0
endfunc

function! s:ListFiles(root, masks)
   let res = []
   for m in a:masks
      if m =~ '^/'
         call extend(res, glob(m, 0, 1))
      else
         call extend(res, glob(a:root . '/' . m, 0, 1))
      endif
   endfor
   return res
   " TODO: prune subprojects
endfunc

function! s:ListProjectFiles(prj)
   let files = []
   let bdir = fnamemodify(a:prj['project-file'], ':h')
   for sec in s:listSections
      if has_key(a:prj, sec)
         let masks = a:prj[sec]
         let lst = s:ListFiles(bdir, masks)
         if len(lst) > 0
            call extend(files, lst)
         endif
      endif
   endfor
   return files
endfunc


function! vimuiex#vxproject#SelectProjectFile()
   let prj = vimuiex#vxproject#GetBufferProject(bufnr('%'))
   if has_key(prj, '*') && has_key(prj['*'], 'all-files')
      let files = prj['*']['all-files']
      " echom "OK"
   else
      if !has_key(prj, 'project-file')
         return
      endif
      let files = [ prj['project-file'] ]
      let lst = s:ListProjectFiles(prj)
      call extend(files, lst)
      if !has_key(prj, '*')
         let prj['*'] = {}
      endif
      let prj['*']['all-files'] = files
   endif
   function s:modfn(fn, bdir)
      let fn = substitute(a:fn, '^' . a:bdir, '@p', '')
      return fnamemodify(fn, ':t') . "\t" . fnamemodify(fn, ':h')
   endfunc
   let bdir = fnamemodify(prj['project-file'], ':h')
   let disp = copy(files)
   call map(disp, s:SNR . 'modfn(v:val, bdir)')
   delfunc s:modfn

   let opts = { 'columns': 1 }
   if has_key(prj, 'title')
      let title = '''' . prj['title'] . ''' files' 
   else
      let title = 'Project files'
   endif
   let rv = popuplist(disp, title, opts)
   if rv.status == 'accept'
      let fn = files[rv.current]
      call vxlib#cmd#Edit(fn, '')
   endif
endfunc

function! s:Test()
   let g:vxproject_project_file = '.vimproject'
   let prj = vimuiex#vxproject#GetBufferProject(bufnr('%'))
   if has_key(prj, 'sources')
      let bdir = fnamemodify(prj['project-file'], ':h')
      let srcs = s:ListFiles(bdir, prj['sources'])
      echom "Sources: " . len(srcs)
   endif
   echom string(prj)
   if s:IsFileInProject(fnamemodify(bufname('%'), ':p'), prj)
      echom bufname('%') . ' is in project ' . prj['title']
   endif
   call vimuiex#vxproject#SelectProjectFile()
endfunc
" =========================================================================== 
" Global Initialization - Processed by Plugin Code Generator
" =========================================================================== 
finish

" <VIMPLUGIN id="vimuiex#vxproject" require="popuplist||python&&(!gui_running||python_screen)">
   " TODO: this should be a list of possible files/file extensions
   " TODO: default name? .vimproject, .vxproject, .vxprj, .vimxprj?
   call s:CheckSetting('g:vxproject_project_file', '".vimproject"')
   call s:CheckSetting('g:vxproject_project_subdir', '".vxproject"')
   command VxProjectFileFilter call vimuiex#vxproject#SelectProjectFile()
   nmap <silent><unique> <Plug>VxProjectFileFilter :VxProjectFileFilter<cr>
" </VIMPLUGIN>
