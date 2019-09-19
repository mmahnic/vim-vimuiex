" vim:set fileencoding=utf-8 sw=3 ts=3 et
" vxbuflist.vim - display a list of buffers in a popup window
"
" Author: Marko Mahnič
" Created: April 2009
" Changed: June 2011
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.
"
" (requires python)

if vxlib#load#IsLoaded( '#vimuiex#vxbuflist' )
   finish
endif
call vxlib#load#SetLoaded( '#vimuiex#vxbuflist', 1 )

" =========================================================================== 
" Local Initialization - on autoload
" =========================================================================== 
if !has('popuplist') && has('python')
   call vxlib#python#prepare()
endif
exec vxlib#plugin#MakeSID()
let s:bufnumbers = []
let g:_VxPopupListPosDefault = get(g:, '_VxPopupListPosDefault', {})
let g:_VxPopupListPosDefault['VxBufListSelect'] = 'minsize=0.4,8'
let g:plug_vxbuflist = get(g:, 'plug_vxbuflist', {})
" =========================================================================== 

let s:bufOrderDef = [ ['m', 'MRU'], ['#', 'BufNr'], ['n', 'Name'], ['e', 'Ext'], ['f', 'Path'] ]
let s:bufOrder = 0
let s:bufFileFormat = 's' " split, normal
let s:bufPath = 'r'       " relative, full
let s:showUnlisted = 0
function s:GetBufOrderStr(lsline)
   let order = s:bufOrderDef[s:bufOrder][0]
   if order == 'm' || order == '#'
      let bo = matchstr(a:lsline, '\s*\zs\d\+\ze')
      if order == '#' | let ai = bo
      else
         let ai = index(g:VxPluginVar.vxbuflist_mru, 0 + bo)
         if ai < 0 | let ai = 99999 | endif
      endif
      return printf('%05d', ai)
   else
      let b_fn = matchstr(a:lsline, '"\zs.\{-}\ze"\s\+line \d\+\s*$')
      if order == 'n' | return fnamemodify(b_fn, ':t')
      elseif order == 'e' 
         try
            return fnamemodify(b_fn, ':e')
         catch /.*/
            return ""
         endtry
      else | return fnamemodify(b_fn, ':p')
      endif
   endif
endfunc

function! s:IsOrderedByMru()
   let order = s:bufOrderDef[s:bufOrder][0]
   return order == 'm'
endfunc

function! s:GetDisplayStr(lsline)
   let b_st = matchstr(a:lsline, '^[^"]\+')
   let b_fn = matchstr(a:lsline, '"\zs.\{-}\ze"\s\+line \d\+\s*$')
   return b_st . fnamemodify(b_fn, ':t') . "\t" . fnamemodify(b_fn, ':h')
endfunc

function! s:GetBufferList()
   let lscmd = s:showUnlisted ? 'ls!' : 'ls'
   let buffs = vxlib#cmd#Capture(lscmd, 1)
   call map(buffs, '[s:GetBufOrderStr(v:val), s:GetDisplayStr(v:val)]')
   call sort(buffs, 1)
   call map(buffs, 'v:val[1]')
   let s:bufnumbers = map(copy(buffs), 'matchstr(v:val, ''\s*\zs\d\+\ze'')')
   return buffs
endfunc

function! s:GetRemoteBufferList()
   " TODO: s:GetRemoteBufferList()
   "  use serverlist()
   "     and vxlib#cmd#Capture("!vim --servername ... --remote-expr getcwd()", 1)
   "     and vxlib#cmd#Capture("!vim --servername ... --remote-expr \"vxlib#cmd#Capture(':ls',1)\"", 1)
   "  or
   "     use remote_expr(<srv_name>, 'getcwd()')
   "     and remote_expr(<srv_name>, "vxlib#cmd#Capture(':ls',1)")
endfunc

function! s:GetTitle()
   let order = s:bufOrderDef[s:bufOrder]
   let title = 'Buffers by ' . order[1]
   return title
endfunc

function! s:SelectBuffer_cb(index, winmode)
   let bnr = s:bufnumbers[a:index]
   call vxlib#cmd#GotoBuffer(0 + bnr, a:winmode)
   return 'q'
endfunc

function! s:SelectMarkedBuffers_cb(marked, index, winmode)
   if len(a:marked) < 1
      return s:SelectBuffer_cb(a:index, a:winmode)
   endif
   only
   let first = 1
   for idx in a:marked
      call s:SelectBuffer_cb(idx, first ? '' : a:winmode)
      let first = 0
   endfor
   return 'q'
endfunc

function! s:ResortItems_cb()
   let s:bufOrder = (s:bufOrder + 1) % len(s:bufOrderDef)
   exec 'python BufList.title="' . s:GetTitle() . '"'
   call s:ReloadBufferList()
   return ""
endfunc

" command: bdelete, bwipeout, bunload
function! s:RemoveBuffer_cb(index, command)
   let nr = s:bufnumbers[a:index]
   exec a:command . ' ' . nr
   call s:ReloadBufferList()
   return ''
endfunc

function! s:ToggleUnlisted_cb()
   let s:showUnlisted = s:showUnlisted ? 0 : 1
   call s:ReloadBufferList()
   return ''
endfunc

function! s:ReloadBufferList()
   exec 'python BufList.loadVimItems("' . s:SNR . 'GetBufferList()")'
endfunc


function! s:PulsBuferList_delete_cb(command, state)
   let rmbfs = []
   if len(a:state.marked) > 0
      for nr in a:state.marked
         call add(rmbfs, s:bufnumbers[nr])
      endfor
   else
      call add(rmbfs, s:bufnumbers[a:state.current])
   endif
   if len(rmbfs) < 1
      return
   endif
   for nr in rmbfs
      exec a:command . ' ' . nr
   endfor
   unlockvar 1 a:state.items
   call remove(a:state.items, 0, len(a:state.items)-1)
   call extend(a:state.items, s:GetBufferList())
   lockvar 1 a:state.items
   return { 'nextcmd': 'auto-resize', 'redraw': 1 }
endfunc

function! s:PulsBuferList_select_cb(command, state)
   let cmd = a:command
   if cmd == 'tabopen' | let cmd = 't'
   elseif cmd == 'split' | let cmd = 's'
   elseif cmd == 'vsplit' | let cmd = 'v'
   else | let cmd = ''
   endif
   if cmd == 't'
      call s:SelectBuffer_cb(a:state.current, cmd)
   else
      call s:SelectMarkedBuffers_cb(a:state.marked, a:state.current, cmd)
   endif
endfunc

function! s:PulsBuferList_display_cb(command, state)
   let cmd = a:command
   if cmd == 'sort'
      let s:bufOrder = (s:bufOrder + 1) % len(s:bufOrderDef)
      " The list may be sorted with a key that is not part of the displayed
      " value so we have to rebuild the list.
   elseif cmd == 'toggle-unlisted'
      let s:showUnlisted = s:showUnlisted ? 0 : 1
   else
      return
   endif

   " The list is locked, the items are not.
   " We have to manipulate the list with remove/extend.
   " If we assign to a:state.items, a new list is created, which is unknown to
   " popuplist().
   unlockvar 1 a:state.items
   call remove(a:state.items, 0, len(a:state.items)-1)
   call extend(a:state.items, s:GetBufferList())
   lockvar 1 a:state.items
   return { 'nextcmd': 'auto-resize', 'title': s:GetTitle(), 'redraw': 1 }
endfunc

" Manage the buffers with VimScript instead of the builtin 'buffers' provider.
" The items are stored in a list may be modified while the listbox is active.
function! s:PulsBuferList()
   let items = s:GetBufferList()
   let cbsel = s:SNR . 'PulsBuferList_select_cb'
   let cbrem = s:SNR . 'PulsBuferList_delete_cb'
   let cbdis = s:SNR . 'PulsBuferList_display_cb'
   let cmds = {
            \ 'bdelete': cbrem, 'bwipeout': cbrem,
            \ 'split': cbsel, 'vsplit': cbsel, 'tabopen': cbsel,
            \ 'sort': cbdis, 'toggle-unlisted': cbdis
            \ }
   let kmaps = {}
   let kmaps['normal'] = { 
            \ 'xd': 'bdelete', 'xw': 'bwipeout',
            \ 'gs': 'split|done:split', 'gv': 'vsplit|done:vsplit', 'gt': 'tabopen|done:tabopen',
            \ 'ou': 'toggle-unlisted', 'os': 'sort',
            \ '<s-cr>': 'accept:tabopen'
            \}
   let opts = { 'commands': cmds, 'keymap': kmaps, 'columns': 1, 'current': 1 }
   let rslt = popuplist(items, s:GetTitle(), opts)
   if rslt.status == 'accept'
      " call vxlib#cmd#GotoBuffer(0 + rslt.current, '')
      call s:PulsBuferList_select_cb('open', rslt)
   elseif rslt.status == 'accept:tabopen'
      call s:PulsBuferList_select_cb('tabopen', rslt)
   endif
endfunc

function! s:PopupBufferList_select_buffer( winid )
   let vxlist = vimuiex#vxpopup#get_vxlist( a:winid )
   let itemIndex = vxlist.get_current_index()
   call s:SelectBuffer_cb( itemIndex, '' )
   call popup_close( a:winid )
endfunc

let s:buflist_keymap = {
         \ "\<cr>" : { win -> s:PopupBufferList_select_buffer( win ) }
         \ }

" This version of popup uses the new popup* set of functions.
function! s:BufListSelect_popup()
   let winid = vimuiex#vxpopup#popup_list( s:GetBufferList(), #{
            \ title: s:GetTitle(),
            \ vxkeymap: [s:buflist_keymap],
            \ vxcurrent: s:IsOrderedByMru() ? 1 : 0
            \ } )
endfunc

" OLD: This version of popuplist was developed in C (more precisely with the
" Minimal Object Oriented C Complier, mmoocc.py).  It defined a new Vim
" function popuplist().
function! s:BufListSelect_popuplist()
   if !has('popuplist')
      return
   endif

   if ! get(g:plug_vxbuflist, 'use_internal', 0)
      call s:PulsBuferList()
   else
      " use the internal buffer provider
      let rslt = popuplist('buffers', 'Buffers', { 
               \ 'mru-list': g:VxPluginVar.vxbuflist_mru, 'sort': 'r',
               \ 'current': 1 } )
      if rslt.status == 'accept'
         call vxlib#cmd#GotoBuffer(0 + rslt.current, '')
      endif
   endif
endfunc

" OLD: The initial version of the Popup List  was implemented in Python. It
" used various backends for displaying the popup (curses, wxPython, custom C
" code).
function! s:BufListSelect_popuplist_python()
   if !has('python')
      return
   endif

   exec 'python def SNR(s): return s.replace("$SNR$", "' . s:SNR . '")'

python << EOF
import vim
import vimuiex.popuplist as lister
BufList = lister.CList(title="Buffers", optid="VxBufListSelect")
BufList._firstColumnAlign = True
EOF
   exec 'python BufList.title="' . s:GetTitle() . '"'
python << EOF
BufList.loadVimItems(SNR("$SNR$GetBufferList()"))
BufList.cmdAccept = SNR("$SNR$SelectBuffer_cb({{i}}, '')")
BufList.keymapNorm.setKey(r"\<s-cr>", SNR("vim:$SNR$SelectBuffer_cb({{i}}, 't')"))
# x-"execute" 
BufList.keymapNorm.setKey(r"xd", SNR("vim:$SNR$RemoveBuffer_cb({{i}}, 'bdelete')"))
BufList.keymapNorm.setKey(r"xw", SNR("vim:$SNR$RemoveBuffer_cb({{i}}, 'bwipeout')"))
# g-"goto" 
BufList.keymapNorm.setKey(r"gs", SNR("vim:$SNR$SelectMarkedBuffers_cb({{M}}, {{i}}, 's')"))
BufList.keymapNorm.setKey(r"gv", SNR("vim:$SNR$SelectMarkedBuffers_cb({{M}}, {{i}}, 'v')"))
BufList.keymapNorm.setKey(r"gt", SNR("vim:$SNR$SelectBuffer_cb({{i}}, 't')"))
# o-"option"
BufList.keymapNorm.setKey(r"ou", SNR("vim:$SNR$ToggleUnlisted_cb()"))
BufList.keymapNorm.setKey(r"os", SNR("vim:$SNR$ResortItems_cb()"))
BufList.process(curindex=1)
BufList=None
EOF
endfunc


function! vimuiex#vxbuflist#VxBufListSelect()
   if ( v:version >= 801 )
      call s:BufListSelect_popup()
      return
   endif
   if has('popuplist')
      call s:BufListSelect_popuplist()
      return
   endif
   if has('python') && !has('gui')
      call s:BufListSelect_popuplist_python()
      return
   endif
   echom "A popup list required by vxbuflist is not available."
endfunc

