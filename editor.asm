.model tiny
.stack
.data
  input_pkt   label byte
    input_cap    db 18
    input_used   db ?
    input_line   db 18 dup (' ')
  border_double db 201,187,200,188,205,186
  border_single db 218,191,192,217,196,179
  title    db 'Text Editor$'
  options  db 'F1 = HELP       CAPS       INS$'
  temp_fname db 'temp.txt'
  msg_f2     db 'F2 = Save File As...$' 
  msg_f3     db 'F3 = Open File$' 
  msg_f4     db 'F4 = New File$' 
  filename_prompt db 'File name: $'
  ok_btn   db '< OK >$'
  notitle  db ' Untitled $'
  file_missing db 'File not found!!$'
  saved_msg db 'File saved$'  
  file_hdl dw ?
  ins_tmp_col db ?
  caps_on     db 0
  insert   db 0
  key_char    db ?
  newline  db 10,13
  blank18 db 18 dup (' ')
  string   db 1520 dup (' ')
  big_blank db 1520 dup (' ')
  spacer78_txt db 78 dup(' '),'$'
  line_scratch db 78 dup(' ')
  drive_ltr db ' :\$' 
  buffer   db 18 dup (' '),'$'
  newline_lit db 10,13,'$'
  ;aux      dw 78
.code
  buffered_line_input macro
    mov ah,0ah
    lea dx,input_pkt
    int 21h
    mov bh,00
    mov bl,input_used
    mov input_line[bx],00h
  endm

.startup
  gotoxy proto c, row_num:byte, col_num:byte
  print_str proto c, str_offs: ptr byte
  draw_box proto c, r1:byte, c1:byte, r2:byte, c2:byte, box_tbl: ptr byte
  paint_rect  proto c, row_num:byte, col_num:byte, row2:byte, col2:byte, attrib:byte
  blk_copy proto c, nbytes:word, dst_bytes: ptr byte, src_bytes:ptr byte
  clear_region  proto c, row_num:byte, col_num:byte, row2:byte, col2:byte
  restore_region  proto c, row_num:byte, col_num:byte, row2:byte, col2:byte
  capture_region  proto c, row_num:byte, col_num:byte, row2:byte, col2:byte
  scrape_canvas  proto c, row_num:byte, col_num:byte, row2:byte, col2:byte
  create_file proto c, path_spec: ptr byte
  open_file_rw proto c, path_spec: ptr byte
  write_file_buf proto c, buf_ptr:ptr byte
  ext_keys proto c, scan_code:byte
  put_tty proto c, ascii_ch:byte
   call clear_screen
   invoke draw_box,1,0,23,79,addr border_single
   invoke paint_rect,2,1,23,79,17h ;17h
   invoke paint_rect,0,0,1,80,70h
   invoke paint_rect,24,0,25,80,70h
   invoke paint_rect,0,31,1,48,87h ;title background
   invoke gotoxy,0,32
   invoke print_str, addr title
   invoke gotoxy,24,1
   invoke print_str, addr options  
   invoke gotoxy,1,34 ;untitled
   invoke print_str, addr notitle
   invoke gotoxy, 2,1
   call input_text
   app_exit_label:
.exit
 create_file proc c, path_spec: ptr byte
    mov ah,3ch
    mov cx,00h
    mov dx,path_spec
    int 21h 
    mov file_hdl,ax
    ret
 create_file endp
 
 open_file_rw proc c, path_spec: ptr byte
   mov ah,3dh
   mov al,02
   mov dx,path_spec
   int 21h 
   ret
 open_file_rw endp
  
 write_file_buf proc c, buf_ptr: ptr byte
   mov ah,40h   
   mov BX,file_hdl
   mov CX,1899;78
   mov DX,buf_ptr
   int 21h
   ret
 write_file_buf endp 
  
 blk_copy proc c, nbytes:word, dst_bytes: ptr byte, src_bytes:ptr byte
   mov cx,nbytes
   mov di,dst_bytes
   mov si,src_bytes
   rep movsb
   ret
 blk_copy endp
  
 clear_screen proc near
   mov ah,00h
   mov al,03h
   int 10h
   ret
 clear_screen endp
 
 current_dir proc near
    mov ah,19h
    int 21h
    mov cl,al 
    add al,41h
    mov drive_ltr,al
    inc cl
    mov ah,47h
    mov dl,cl
    lea si,buffer
    int 21h
    ret
  current_dir endp
 
 help_window proc near
   invoke capture_region,7,19,17,61;save screen characters in this region 
   invoke clear_region,7,19,17,61
   invoke paint_rect,9,21,18,63,00h ;shadow layer
   invoke paint_rect,7,19,17,61,70h 
   invoke draw_box,7,19,16,60,addr border_single
   invoke gotoxy, 9,30  
   invoke print_str,addr msg_f2
   invoke gotoxy, 11,30  
   invoke print_str,addr msg_f3
   invoke gotoxy, 13,30  
   invoke print_str,addr msg_f4
   invoke gotoxy, 15,34  
   invoke print_str,addr ok_btn
   invoke paint_rect,15,34,16,45,87h
   invoke paint_rect,24,0,25,12,0e0h
   invoke gotoxy, 15,45
   wait_enter:
     mov ah,08h
     int 21h
     cmp al,13
     je help_done
     jmp wait_enter
     help_done:
       invoke restore_region,7,19,17,61  ;restore previously saved characters
       invoke paint_rect,7,19,18,63,17h 
       invoke paint_rect,24,0,25,12,70h; F1 help: restore status bar color
   ret
 help_window endp

 inner_frame proc near
   invoke capture_region,7,19,15,63;save screen characters in this region 
   invoke clear_region,7,19,15,63
   invoke paint_rect,9,21,15,63,00h ;shadow layer
   invoke paint_rect,7,19,14,61,70h 
   invoke draw_box,7,19,13,60,addr border_single
   ret
 inner_frame endp


 ext_keys proc c, scan_code:byte
   mov ah,03h
   mov bh,00
   int 10h    
   cmp scan_code,50h;50h;down arrow
   je key_dn
   cmp scan_code,48h;4bh;up arrow
   je key_up
   cmp scan_code,4dh;right arrow
   je key_rt
   cmp scan_code,4bh;left arrow
   je key_lt
   cmp scan_code,47h;home (line start)
   je key_home
   cmp scan_code,4fh;end (line end)
   je ln_end
   cmp scan_code,3bh;f1
   je f1_handler
   cmp scan_code,3ch;f2
   je f2
   cmp scan_code,3dh;f3
   je f3
   cmp scan_code,3eh ;f4
   je f4
   cmp scan_code,3fh;f5 exit program
   je f5
   cmp scan_code,3ah; Caps Lock
   je caps_toggle
   cmp scan_code,52h;Insert mode
   je ins_toggle
   jmp sp_done
   ins_toggle:
    mov ah,08h
    mov bh,00h
    int 10h
    push dx
    cmp insert,0 
    jne ins_off_paint
     invoke paint_rect,24,27,25,35,0e0h
     mov insert,1    
     jmp insert_mode_done
    ins_off_paint:
      invoke paint_rect,24,27,25,35,70h
     mov insert,0    
    insert_mode_done:
    pop dx
    invoke gotoxy, dh,dl
    jmp sp_done
   caps_toggle:
    mov ah,08h
    mov bh,00h
    int 10h
    push dx
    cmp caps_on,1
    jne caps_off_paint
      invoke paint_rect,24,16,25,23,70h
      mov caps_on,0
      jmp caps_toggle_done
    caps_off_paint:
    invoke paint_rect,24,16,25,23,0e0h
    mov caps_on,1
    pop dx
    caps_toggle_done:
    invoke gotoxy, dh,dl
    jmp sp_done
   f4:
     invoke draw_box,1,0,23,79,addr border_single
     invoke clear_region,2,1,23,79;clear region
     invoke paint_rect,2,1,23,79,17h
     invoke gotoxy,1,34 ;untitled
     invoke print_str, addr notitle
     invoke gotoxy,2,1
     jmp sp_done
   f3:
     mov ah,08h
     mov bh,00h
     int 10h
     push dx
     call inner_frame
     invoke gotoxy, 9,21  
     invoke print_str,addr filename_prompt
     invoke blk_copy, 18,addr blank18,addr input_line
     buffered_line_input
     invoke clear_region,7,19,15,63
     invoke restore_region,7,19,15,63  ;restore previously saved characters
     invoke paint_rect,7,19,15,63,17h 
     invoke scrape_canvas,2,1,23,78
     invoke open_file_rw, addr input_line
     mov file_hdl,ax 
     cmp ax,02h
     jne open_flow
       call inner_frame
       invoke gotoxy, 9,21  
       invoke print_str,addr file_missing
       wait_retry_enter:  ;if file not found
         mov ah,08h
         int 21h
         cmp al,13
         jne wait_retry_enter
         invoke clear_region,7,19,15,63
         invoke restore_region,7,19,15,63  ;restore previously saved characters
         invoke paint_rect,7,19,15,63,17h 
         pop dx
         invoke gotoxy, dh,dl
         jmp sp_done  
     open_flow:
       invoke clear_region,2,1,23,79
       invoke blk_copy, 1520,addr big_blank,addr string
       mov ah,3fh
       mov bx,file_hdl
       lea dx,string
       mov cx,1520;aux ;78 ;aux;1899
       int 21h 
       mov ch,2
       mov di,0
       draw_lines_loop:  
         invoke gotoxy,ch,1
         mov si,0
         inner_col_lp:
          cmp string[di],10
          jne not_nl
            invoke put_tty,244
          not_nl:
          invoke put_tty,string[di] 
          inc di
          inc si 
          cmp si,78
          jne inner_col_lp 
        inc ch
        cmp ch,23
        jne draw_lines_loop
       invoke draw_box,1,0,23,79,addr border_single
       ;refresh current directory
       invoke blk_copy, 18,addr blank18,addr buffer
       call current_dir
       mov al,20h
       mov cx,18
       lea di,buffer
       repne scasb
       jne path_done_open
         mov buffer[di],5ch ;  
         mov buffer[di+1],24h ;$
         invoke gotoxy,1,29 
         invoke print_str,addr drive_ltr 
         invoke print_str,addr buffer
         mov bl,input_used
         mov input_line[bx],'$'
         invoke print_str,addr input_line
       path_done_open:  
        pop dx
        invoke gotoxy, dh,dl
        jmp sp_done
      
   f2:
     mov ah,08h
     mov bh,00h
     int 10h
     push dx
     call inner_frame
     invoke gotoxy, 9,21  
     invoke print_str,addr filename_prompt
     invoke blk_copy, 18,addr blank18,addr input_line
     buffered_line_input
     invoke clear_region,7,19,15,63
     invoke restore_region,7,19,15,63  ;restore previously saved characters
     invoke paint_rect,7,19,15,63,17h 
     invoke scrape_canvas,2,1,23,78
     invoke open_file_rw, addr input_line
     mov file_hdl,ax 
     cmp ax,02h
     jne save_flow
       invoke create_file, addr input_line        
     save_flow:
       invoke write_file_buf,addr string
       mov ah,3EH  ;close file 
	   mov BX,file_hdl
	   int 21h
       invoke gotoxy,24,60
       invoke print_str,addr saved_msg 
     ;refresh current directory
       invoke blk_copy, 18,addr blank18,addr buffer
       call current_dir
       mov al,20h
       mov cx,18
       lea di,buffer
       repne scasb
       jne path_done_save
         mov buffer[di],5ch ;  
         mov buffer[di+1],24h ;$
         invoke gotoxy,1,29 
         invoke print_str,addr drive_ltr 
         invoke print_str,addr buffer
         mov bl,input_used
         mov input_line[bx],'$'
         invoke print_str,addr input_line
       path_done_save: 
       pop dx
       invoke gotoxy,dh,dl
       push dx
       mov ah,08h
       int 21h
       invoke gotoxy,24,60
       invoke clear_region,24,60,25,78
       pop dx
       invoke gotoxy,dh,dl
     jmp sp_done
   f5:
    mov ax,4c00h
    int 21h  
   f1_handler:
     mov ah,08h
     mov bh,00h
     int 10h
     push dx
     call help_window
     pop dx
     invoke gotoxy, dh,dl 
     jmp sp_done
   key_home:
     invoke gotoxy, dh,1
     jmp sp_done
   ln_end:
     invoke gotoxy, dh,77
     jmp sp_done
   key_lt:
     cmp dl,1
     jne move_left_step
     jmp sp_done
     move_left_step:
       sub dl,1
       invoke gotoxy, dh,dl
       jmp sp_done
   key_rt:
     cmp dl,77
     jne move_right_step
     jmp sp_done
     move_right_step:
       add dl,1
       invoke gotoxy, dh,dl
       jmp sp_done
   key_up:
     cmp dh,2
     jne dec_row
     jmp sp_done
     dec_row:
       sub dh,1
       invoke gotoxy,dh,dl 
       jmp sp_done
   key_dn:
    cmp dh,22
    jne inc_row
    jmp sp_done  
    inc_row:
      add dh,1
      invoke gotoxy, dh,dl   
      jmp sp_done
  sp_done:
   ret
 ext_keys endp
 
 scrape_canvas  proc c, r1:byte, c1:byte, r2:byte, c2:byte
     invoke blk_copy, 1520,addr big_blank,addr string
     mov di,0
     mov ch,r1
     scrape_row:
      mov cl,c1
      scrape_col:
         invoke gotoxy,ch,cl ;**move cursor and read attribute**
         mov ah,08h
         mov bh,00h
         int 10h
         cmp al,244;40h;'ù';244
         jne not_para
           mov string[di],10;0eh;10
           inc di
          mov string[di],13;1ch;13
          jmp adv_char
         not_para:
         mov string[di],al
         adv_char:
         inc cl
         inc di
         cmp cl,c2
         jne scrape_col
      inc ch
      cmp ch,r2
      jne scrape_row
     mov string[di],'$' 
     ret
  scrape_canvas endp
 
 insert_shift proc near
    mov ah,03h
    mov bh,00h
    int 10h
     cmp al,08
     je ins_skip_bs
     sub dl,2
     mov ins_tmp_col,dl
     mov dl,76
     shift_cells:
      invoke gotoxy,dh,dl
      mov ah,08h
      mov bh,00h
      int 10h
      push ax
      add dl,1
      invoke gotoxy,dh,dl
      pop ax
      push dx
      invoke put_tty,al
      pop dx
      sub dl,2
      cmp dl,ins_tmp_col
      jne shift_cells
    add ins_tmp_col,2
    invoke gotoxy, dh,ins_tmp_col  
    ins_skip_bs:
   ret
 insert_shift endp
 
 input_text proc near
   edit_loop:
     call clamp_cursor
     push dx
     cmp dh,22
     jne top_row_chk
       cmp dl,77
       je noecho
     top_row_chk:
     mov ah,00h
     int 16h
     cmp al,00h
     jne got_keybd
       invoke ext_keys, ah
	   jmp edit_loop	
     got_keybd:
      mov key_char,al
      cmp insert,1
      jne no_ins
        call insert_shift
      no_ins:
      invoke put_tty, key_char
      after_write:
      cmp al,08
      je backspace_bs
      cmp al,13
      je enter_key
     jmp edit_loop
   noecho:
       mov ah,08h
       int 21h
       cmp al,08
       je backspace_bs
       invoke put_tty, 07h
       mov ah,03h
       mov bh,00
       int 10h 
       invoke gotoxy, dh,dl
       jmp edit_loop

   backspace_bs:
       call clamp_cursor
       mov ch,dh
       mov cl,dl
       cmp cl,1
       jne default_erase
       cmp ch,2
       je default_erase
        invoke put_tty, 0
        sub ch,1
        invoke gotoxy, ch,77
         
        invoke put_tty, 0
        invoke gotoxy, ch,77
       jmp edit_loop
         
   default_erase:
         mov ah,03h
         mov bh,00h
         int 10h
         cmp dl,1
         jne col_gt_one_erase
          invoke gotoxy, dh,2
          mov ah,08h
          mov bh,00h
          int 10h
          push ax
          invoke gotoxy, dh,1
          pop ax
          push dx
          invoke put_tty, al
          jmp erase_line_done
          
         col_gt_one_erase:
         push dx
         inc dl
         
         shuffle_left:
           push dx
           invoke gotoxy,dh,dl
           pop dx
           dec dl
           mov ah,08h
           mov bh,00h
           int 10h
          
           push ax
           invoke gotoxy, dh,dl
           pop ax
           push dx
           invoke put_tty, al
           pop dx
           add dl,2
           cmp dl,79
           jne shuffle_not_end
             invoke gotoxy, dh,78
             invoke put_tty, 0
             jmp erase_line_done
           shuffle_not_end:
           jmp shuffle_left
         erase_line_done:
         pop dx
         invoke gotoxy, dh,dl
        jmp edit_loop
       
   enter_key:  
       pop dx
       invoke gotoxy, dh,dl
       invoke put_tty, 244;40h;244  ; paragraph symbol (pseudo CR/LF marker)
       inc dh
       invoke gotoxy, dh,1 
       jmp edit_loop  
   ret
 input_text endp

 clamp_cursor proc near
    mov ah,03h
    mov bh,00
	int 10h
    cmp dh,23
    je row_overflow
    cmp dl,78
    je col_overflow
    cmp dl,0
    je col_underflow   
    jmp clamp_done
    row_overflow:
        invoke gotoxy, 22,dl
        jmp clamp_done
    col_underflow:
      invoke gotoxy, dh,1
      jmp clamp_done
   col_overflow:
      add dh,1
      invoke gotoxy, dh,1
   clamp_done:
   ret
 clamp_cursor endp
 
 print_str proc c, str_offs: ptr byte
   mov ah,09h
   mov dx,str_offs
   int 21h
   ret
 print_str endp
 
 gotoxy proc c, row_num:byte, col_num:byte
   mov ah,02h
   mov dh,row_num
   mov dl,col_num
   mov bh,00h
   int 10h
   ret
 gotoxy endp
 
 put_tty proc c, ascii_ch:byte
    mov ah,02h 
	mov dl,ascii_ch 
	int 21h
    ret
 put_tty endp 

 draw_box proc c, r_top:byte,col_left:byte,r_bot:byte,col_right:byte,  box_tbl: ptr byte 
    mov bx,box_tbl
    mov cl,col_left
    draw_top_bot:
      push bx
      invoke gotoxy, r_top,cl 
      pop bx
	  mov bx,box_tbl
	  invoke put_tty, [bx+4] 
	  push bx
	  invoke gotoxy, r_bot,cl
	  mov bx,box_tbl
	  pop bx
	  invoke put_tty, [bx+4] 
	  inc cl	
	  cmp cl,col_right
      jne draw_top_bot
    mov cl,r_top 
    draw_sides:
	  push bx
	  invoke gotoxy, cl,col_left
	  pop bx
      invoke put_tty, [bx+5]
      push bx
	  invoke gotoxy, cl,col_right
	  pop bx
	  invoke put_tty, [bx+5]
	  inc cl
	  cmp cl,r_bot
	  jne draw_sides
    invoke gotoxy, r_top,col_left ;top-left corner**
    mov bx,box_tbl
    invoke put_tty, [bx]
    invoke gotoxy, r_top,col_right ;top-right corner***
	mov bx,box_tbl
    invoke put_tty, [bx+1]
    invoke gotoxy, r_bot,col_left ;bottom-left corner**
	mov bx,box_tbl
    invoke put_tty, [bx+2]
    invoke gotoxy, r_bot,col_right ;bottom-right corner***
	mov bx,box_tbl
    invoke put_tty, [bx+3]
    ret
  draw_box endp
  
   restore_region  proc c, r1:byte, c1:byte, r2:byte, c2:byte
     mov di,0
     mov ch,r1
     rest_row:
      mov cl,c1
      rest_col:
         invoke gotoxy,ch,cl ;**move cursor and read attribute**
         invoke put_tty, string[di]         
         inc cl
         inc di
         cmp cl,c2
         jne rest_col
      inc ch
      cmp ch,r2
      jne rest_row
     ret
  restore_region endp
  
   capture_region  proc c, r1:byte, c1:byte, r2:byte, c2:byte
     invoke blk_copy, 1540,addr big_blank,addr string
     mov di,0
     mov ch,r1
     cap_row:
      mov cl,c1
      cap_col:
         invoke gotoxy,ch,cl ;**move cursor and read attribute**
         mov ah,08h
         mov bh,00h
         int 10h
         mov string[di],al
         inc cl
         inc di
         cmp cl,c2
         jne cap_col
      inc ch
      cmp ch,r2
      jne cap_row
     mov string[di],'$' 
     ret
  capture_region endp
  
  clear_region  proc c, r1:byte, c1:byte, r2:byte, c2:byte
     mov ch,r1
     clr_row:
      mov cl,c1
      clr_col:
         invoke gotoxy,ch,cl ;**move cursor and read attribute**
         invoke put_tty, 0
         inc cl
         cmp cl,c2
         jne clr_col
      inc ch
      cmp ch,r2
      jne clr_row
     ret
   clear_region endp
   
  paint_rect  proc c, r1:byte, c1:byte, r2:byte, c2:byte, attrib:byte
     mov ch,r1
     paint_row:
      mov cl,c1
      paint_col:
         invoke gotoxy,ch,cl ;**move cursor and read attribute**
         mov ah,08h
         mov bh,00h
         int 10h
         mov dh,ch   ;stash row in dh
         mov dl,cl
         mov ah,09h  ;set character attribute
		 mov bh,00h
         mov bl,attrib
         mov cx,1
         int 10h
         mov ch,dh  ;restore row counter
         mov cl,dl         
         inc cl
         cmp cl,c2
         jne paint_col
      inc ch
      cmp ch,r2
      jne paint_row
     ret
   paint_rect endp
end