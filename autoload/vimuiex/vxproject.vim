" vim:set fileencoding=utf-8 sw=3 ts=3 et
" vxproject.vim 
"  - define a list of files that belong to a project
"  - jump to a file from the project or included projects 
"
" Author: Marko Mahnič
" Created: October 2012
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.

let g:loadedPlugAuto = get(g:, 'loadedPlugAuto', {})
if get(g:loadedPlugAuto, 'vimuiex_vxproject', 0)
   finish
endif
let g:loadedPlugAuto.vimuiex_vxproject = 1

let s:pyscript = fnamemodify(expand('<sfile>'), ':p:h:h:h') . '/modpython/script/vxprj-listfiles.py'

" =========================================================================== 
" Local Initialization - on autoload
" =========================================================================== 
exec vxlib#plugin#MakeSID()
" =========================================================================== 

function! s:Strip(input_string)
   return substitute(a:input_string, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction

function! s:StripSection(input_string)
   return substitute(a:input_string, '^\%(\[\|\s\)*\(.\{-}\)\%(\s\|\]\)*$', '\1', '')
endfunction

function! s:RStrip(input_string)
   return substitute(a:input_string, '^\(.\{-}\)\s*$', '\1', '')
endfunction

let s:Projects = {}

function! s:Prj_GetTitle() dict
   if has_key(self, 'title')
      return self.title
   endif
   if has_key(self, 'project-file')
      let fp = self['project-file']
      let fn = fnamemodify(fp, ':t')
      if fn =~ '\M^.'
         let fn = fnamemodify(fp, ':p:h:t') . fn
      endif
      return fn
   endif
   return "Project"
endfunc

function! s:Prj_HasOption(name) dict
   return has_key(self, '*') && has_key(self['*'], a:name)
endfunc

function! s:Prj_GetOption(name, default) dict
   if self.hasOption(a:name)
      return self['*'][a:name]
   endif
   return a:default
endfunc

function! s:Prj_SetOption(name, value) dict
   if !has_key(self, '*')
      let self['*'] = {}
   endif
   let self['*'][a:name] = a:value
endfunc

" Get the contents of the @p section if it exists or an empty list if it
" doesn't.
function! s:Prj_GetSection(section) dict
   if has_key(s:sectionAlias, a:section)
      let section = s:sectionAlias[a:section]
   else
      let section = a:section
   endif
   if has_key(self, section)
      return self[section]
   endif
   return []
endfunc

" get the list of project files either from cache or by listing the FS
function! s:Prj_GetFiles() dict
   " TODO: file-cache could be saved in a file if memory size is an issue
   if self.hasOption('all-files')
      let files = self.getOption('all-files', [])
      " echom "OK"
   else
      if !has_key(self, 'project-file')
         return []
      endif
      let files = [ self['project-file'] ]
      let lst = s:ListProjectFiles(self)
      call extend(files, lst)
      call self.setOption('all-files', files)
   endif
   return files
endfunc

" Create a new project "object" associated with file @p projectfile.
function! s:NewProject(projectfile)
   return { 'project-file': a:projectfile,
            \ 'getTitle':       function(s:SNR . "Prj_GetTitle"),
            \ 'getSection':     function(s:SNR . "Prj_GetSection"),
            \ 'hasOption':      function(s:SNR . "Prj_HasOption"),
            \ 'getOption':      function(s:SNR . "Prj_GetOption"),
            \ 'setOption':      function(s:SNR . "Prj_SetOption"),
            \ 'getFiles':       function(s:SNR . "Prj_GetFiles")
            \  }
endfunc

" some sections, like ctags, can reference other sections like '@sources'
function! s:ExpandReferences(project, section)
endfunc

" Search for project files in @p startdir and its parents.
" Currently the first project file that is found is used. This means there can
" only be one file per project. The file belongs to the first found project
" even if it isn't listed in any of the sections.
"
" TODO: load every project file and verify if the file for which the project
" is searched belongs to the project.
" TODO: verify in the loaded projects, first
function! s:FindProjectFile(startdir)
   if g:vxproject_project_file == "" 
      return ""
   endif
   let cwd = fnamemodify(a:startdir, ':p')
   let prevdir = ""
   while cwd != prevdir
      let fn = cwd . '/' . g:vxproject_project_file
      if filereadable(fn)
         " echom "DEBUG: File readable: " . fn
         return fn
      endif
      let prevdir = cwd
      let cwd = fnamemodify(cwd, ':h')
   endwhile
   return ""
endfunc

function! s:FindScmRoot(startdir)
   let cwd = fnamemodify(a:startdir, ':p')
   let prevdir = ""
   while cwd != prevdir
      if isdirectory( cwd . '/.git' ) || isdirectory( cwd . '/.hg' )
         return cwd
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

" Read the project file @p fname into a dictionary object.
" [section]
" [.subsection] - not used/detected
function! s:LoadProject(fname)
   let project = s:NewProject( a:fname )
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

function! s:CreateScmProject(fname)
   let root = fnamemodify(fname, ':p:h' )
   let name = fnamemodify(root, ':t')
   let project = s:NewProject( root )
   let project['ignore'] = [
            \ '**/' . name . '/.git/',
            \ '**/' . name . '/.hg/',
            \ '**/' . name . '/Build/',
            \ '**/' . name . '/build/',
            \ '**/' . name . '/dfgbuild/' ]
   let project['title'] = name

   return project
endfunc

" Get the project that was read from @p projectfile. Read it if it isn't
" already loaded.
function! s:GetProject(projectfile)
   let prjfile = fnamemodify(a:projectfile, ':p')
   let prjkey = simplify(prjfile) " alternative: resolve()
   let prj = {}
   if has_key(s:Projects, prjkey)
      " echom "FOUND"
      let prj = s:Projects[prjkey]
   else
      " echom "LOADING"
      if (filereadable(prjfile))
         let prj = s:LoadProject(prjfile)
         " echom "DEBUG: File Project: " . a:projectfile
         let s:Projects[prjkey] = prj
      elseif (isdirectory( prjfile ))
         let prj = s:CreateScmProject(prjfile)
         " echom "DEBUG: SCM Project: " . a:projectfile
         let s:Projects[prjkey] = prj
      endif
   endif
   return prj
endfunc

" Get the project settings for buffer @p bufnr
function! vimuiex#vxproject#GetBufferProject(bufnr)
   let prj = getbufvar(a:bufnr, 'vxproject')
   if type(prj) == type({})
      return prj
   endif
   unlet prj
   let prjfile = s:FindProjectFile(fnamemodify(bufname(a:bufnr), ':p:h'))
   if prjfile != ""
      let prj = s:GetProject(prjfile)
   else
      " echom "DEBUG: No project file: "
      let scmdir = s:FindScmRoot( fnamemodify(bufname(a:bufnr), ':p:h') )
      if scmdir != ""
         let prj = s:GetProject(scmdir)
      else
         let prj = {}
      endif
   endif
   call setbufvar(a:bufnr, 'vxproject', prj)
   return prj
endfunc

" Match fullpath to mask using glob() rules.
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

" Check if the file @p fullpath matches any of the patterns of the project.
function! s:IsFileInProject(fullpath, prj)
   let bdir = fnamemodify(a:prj['project-file'], ':h')
   for sec in s:listSections
      if !has_key(a:prj, sec)
         continue
      endif
      let masks = a:prj[sec]
      for m in masks
         if m =~ '^/'
            let found = s:FilepathMatch(a:fullpath, m)
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

" List files in directory that match any of the globbing expressions in masks.
" Can recurse directories.
" TODO: currently duplicate entries could be present in the resulting list
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

" glob for project files on disk
function! s:ListProjectFiles_vim(prj)
   let files = []
   let bdir = fnamemodify(a:prj['project-file'], ':h')
   for sec in s:listSections
      let masks = a:prj.getSection(sec)
      if len(masks) > 0
         let lst = s:ListFiles(bdir, masks)
         if len(lst) > 0
            call extend(files, lst)
         endif
      endif
   endfor
   return files
endfunc

function! s:ListProjectFiles(prj)
   if g:vxproject_lister == "syspython" 
      return s:ListProjectFiles_syspython(a:prj)
   endif
   return s:ListProjectFiles_vim(a:prj)
endfunc

function! s:ListProjectFiles_syspython(prj)
   let files = []
   let projfile = fnamemodify(a:prj['project-file'], ':p')
   let cmd = "!python " . s:pyscript . " " . projfile
   if has('gui_running') != 0
      let flist = vxlib#cmd#Capture(cmd, 1)
   else
      if cmd =~ '^\s*!'
         let flist = vxlib#cmd#CaptureShell(cmd)
      else
         let flist = vxlib#cmd#Capture(cmd, 1)
      endif
   endif
   call filter(flist, 'v:val =~ "^/"')
   return flist
endfunc

" Find all the files that belong to the project and display them in a popup
" list. Edit the file when it is selected.
"
" Files from the included projects can also be listed if the user toggles this
" option by pressing 'oi' while the list is displayed (and the filter is
" inactive).
"
" TODO: option/toggle to list files from subprojects
" TODO: create a virtual file system and give it to VxFileBrowse
function! vimuiex#vxproject#SelectProjectFile()
   let prj = vimuiex#vxproject#GetBufferProject(bufnr('%'))
   if len(prj) < 1
      echom "No project was found for current buffer."
      return
   endif
   let listIncludes = prj.getOption('list-includes', 0)
   let files = prj.getFiles() " s:GetProjectFiles(prj)

   function s:modfn(fn, bdir, prefix)
      let fn = substitute(a:fn, '^' . a:bdir, a:prefix, '')
      return fnamemodify(fn, ':t') . "\t" . fnamemodify(fn, ':h')
   endfunc
   let bdir = fnamemodify(prj['project-file'], ':h')

   " TODO: user-option to start in filter mode by default?
   let opts = { 'columns': 1, 'mode': 'normal',
            \ 'keymap': { 'normal': { 'oi': 'done:toggle-includes' }}
            \ }
   let title = '''' . prj.getTitle() . ''' files'

   let repeat = 1
   while repeat
      let repeat = 0
      let allFiles = copy(files)
      let disp = copy(files)
      call map(disp, s:SNR . 'modfn(v:val, bdir, "@")')

      if listIncludes && has_key(prj, 'includes')
         let incls = prj['includes']
         for inc in incls
            let inc = s:Strip(inc)
            if inc =~ '^#' || inc =~ '^[a-z]\+:\s*$'
               continue
            endif
            if inc !~ '^/.*'   " not an absolute path
               let inc = simplify(bdir . '/' . inc)
            endif
            let idir = fnamemodify(inc, ':p:h')
            let ip = s:GetProject(inc)
            if len(ip) < 1
               continue
            endif
            let ifiles = ip.getFiles() " s:GetProjectFiles(ip)
            if len(ifiles) < 1
               continue
            endif
            let idisp = copy(ifiles)
            " XXX: ip['title'] could fail !
            call map(idisp, s:SNR . 'modfn(v:val, idir, "I:' . ip.getTitle() . ':")')
            call extend(disp, idisp)
            call extend(allFiles, ifiles)
         endfor
      endif

      let rv = popuplist(disp, title, opts)
      if rv.status == 'done:toggle-includes'
         let listIncludes = !listIncludes
         let repeat = 1
         let opts['mode'] = rv.mode
         call prj.setOption('list-includes', listIncludes)
      elseif rv.status == 'accept'
         let fn = allFiles[rv.current]
         call vxlib#cmd#Edit(fn, '')
      endif
   endwhile " repeat
   delfunc s:modfn
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
