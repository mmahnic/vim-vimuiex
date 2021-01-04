" vim: set fileencoding=utf-8 sw=3 ts=8 et:vim
" jump.vim - quick jumping around
"
" Author: Marko Mahnič
" Created: June 2009
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.
"
" (requires python; requires python_screen vim patch)

if vxlib#load#IsLoaded( '#vimuiex#vxjump' )
   finish
endif
call vxlib#load#SetLoaded( '#vimuiex#vxjump', 1 )

" =========================================================================== 
" Local Initialization - on autoload
" =========================================================================== 
if has('python')
   call vxlib#python#prepare()
endif
" =========================================================================== 

function! vimuiex#vxjump#VxLineJump()
" exec 'python VIM_SNR_VXTEXTMENU="' . s:SNR .'"'

python << EOF
import vim
import vimuiex.jumping as vxjmp
Jump = vxjmp.CLineJump()
Jump.process()
Jump=None
EOF

endfunc

function! vimuiex#vxjump#VxWindowJump()
" exec 'python VIM_SNR_VXTEXTMENU="' . s:SNR .'"'

python << EOF
import vim
import vimuiex.jumping as vxjmp
Jump = vxjmp.CWindowJump()
Jump.process()
Jump=None
EOF

endfunc

" =========================================================================== 
" Global Initialization - Processed by Plugin Code Generator
" =========================================================================== 
finish

" <VIMPLUGIN id="vimuiex#vxjump" require="python&&python_screen">
   command VxLineJump call vimuiex#vxjump#VxLineJump()
   command VxWindowJump call vimuiex#vxjump#VxWindowJump()
   nmap <silent><unique> <Plug>VxLineJump :VxLineJump<cr>
   imap <silent><unique> <Plug>VxLineJump <Esc>:VxLineJump<cr>
   vmap <silent><unique> <Plug>VxLineJump :<c-u>VxLineJump<cr>
   nmap <silent><unique> <Plug>VxWindowJump :VxWindowJump<cr>
   imap <silent><unique> <Plug>VxWindowJump <Esc>:VxWindowJump<cr>
   vmap <silent><unique> <Plug>VxWindowJump :<c-u>VxWindowJump<cr>
" </VIMPLUGIN>

