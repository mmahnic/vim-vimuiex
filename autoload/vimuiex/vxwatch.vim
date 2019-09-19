" vim: set fileencoding=utf-8 sw=3 ts=8 et
" vxwatch.vim - Hierarchical display of Vim variables.
"
" Author: Marko Mahnič
" Created: May 2011
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.

if vxlib#load#IsLoaded( '#vimuiex#vxwatch' )
   finish
endif
call vxlib#load#SetLoaded( '#vimuiex#vxwatch', 1 )

if !has('popuplist')
   call vxlib#load#SetError( '#vimuiex#vxwatch', 'Missing: popuplist' )
   call vxlib#load#SetError( '#vimuiex#vxwatch', 'TODO: vxpopup' )
   finish
endif

" =========================================================================== 
" Local Initialization - on autoload
" =========================================================================== 
" exec vxlib#plugin#MakeSID()
" =========================================================================== 

function! s:DumpDict(dict)
   let keys = keys(a:dict)
   call sort(keys)
   let strs = []
   let v = 0
   for k in keys
      call add(strs, string(k) . "\t" . string(a:dict[k]))
   endfor
   return strs
endfunc

function! s:DumpList(list)
   let strs = []
   let i = 0
   for li in a:list
      call add(strs, string(i) . "\t" . string(li))
      let i = i + 1
   endfor
   return strs
endfunc

function! s:MakeItems(var)
   if type(a:var) == type([])
      let items = s:DumpList(a:var)
   elseif type(a:var) == type({})
      let items = s:DumpDict(a:var)
   else
      let items = [string(a:var)]
   endif
   return items
endfunc

function! s:CanExpand(var)
   if type(a:var) == type([])
      return 1
   elseif type(a:var) == type({})
      return 1
   endif
   return 0
endfunc

function! s:MakeTitle(stack)
   let title = ''
   for cur in a:stack
      let title = title . cur[3]
   endfor
   return title
endfunc

function! vimuiex#vxwatch#VxWatch(variable, title)
   if !has('popuplist')
      return
   endif
   let opts = {
            \ 'keymap': {
            \   'normal': { '<backspace>': 'done:go-up' },
            \ },
            \ 'mode': 'normal',
            \ 'current': 0,
            \ 'columns': 1
            \ }
   let stack = [ [a:variable, s:MakeItems(a:variable), 0, a:title] ]
   let spos = 0
   let var = 0
   let items = 0

   while 1
      let cur = stack[spos]
      unlet var
      let var = cur[0]
      unlet items
      let items = cur[1]
      let opts.current = cur[2]

      let rv = popuplist(items, "Watch " . s:MakeTitle(stack), opts)
      if rv.status == 'done:go-up'
         if spos > 0
            let spos = spos - 1
            let stack = stack[:spos]
         else
            let cur[2] = rv.current
         endif
         let opts.mode = rv.mode
      elseif rv.status == 'accept'
         let cur[2] = rv.current
         let selitem = 0
         if type(var) == type([])
            unlet selitem
            let selitem = var[rv.current]
            let title = '[' . rv.current . ']'
         elseif type(var) == type({})
            let key = matchstr(items[rv.current], '^''\zs.\{-}\ze''\t')
            if has_key(var, key)
               unlet selitem
               let selitem = var[key]
               let title = '.' . key
            endif
         endif
         if s:CanExpand(selitem)
            call add(stack, [selitem, s:MakeItems(selitem), 0, title])
            let spos = len(stack) - 1
         endif
         unlet selitem
         let opts.mode = rv.mode
      else
         break
      endif
   endwhile
endfunc

function! vimuiex#vxwatch#VxWatchAll()
   let vars = vxlib#cmd#Capture("let", 1)
   call map(vars, 'matchstr(v:val, "^.\\{-}\\ze\\s")')
   let l:vard = {}
   for v in vars
      if len(v) > 0
         if v[1] != ':'
            let v = 'g:' . v
         endif
         if v[0] != 'l' && v[0] != 's'
            exec 'let l:vard["' . v . '"] = '. v
         endif
      endif
   endfor
   call vimuiex#vxwatch#VxWatch(l:vard, "{Vim}")
endfunc

