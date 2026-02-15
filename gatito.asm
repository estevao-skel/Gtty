section .data
    clear_screen db 27,'[2J',27,'[H'
    status_bar db 27,'[24;1H',27,'[1;33;40m ctrl+s=salvar  ctrl+q=sair  ctrl+l=ocultar  ctrl+k=recortar ',27,'[0m'
    prompt_save db 27,'[24;1H',27,'[K',27,'[1;33;40m nome: ',27,'[0m',27,'[1;37m'
    msg_saved db 27,'[24;1H',27,'[K',27,'[1;33;40m salvo! ',27,'[0m'
    color_white db 27,'[1;37m'
    color_gray db 27,'[38;5;240m'
    scroll_region db 27,'[1;23r'
    reset_scroll db 27,'[r'

section .bss
    buffer resb 4096
    filename resb 260
    cursor_x resb 1
    cursor_y resb 1
    buf_pos resw 1
    termios_orig resb 60
    termios_new resb 60
    char resb 1
    fname_len resq 1
    show_lines resb 1
    line_offset resb 1
    current_line resw 1

section .text
    global _start

_start:
    mov rax, 16
    xor rdi, rdi
    mov rsi, 0x5401
    mov rdx, termios_orig
    syscall
    
    mov rcx, 60
    mov rsi, termios_orig
    mov rdi, termios_new
    rep movsb
    
    and dword [termios_new + 12], ~26
    and dword [termios_new], ~1024
    mov byte [termios_new + 16], 1
    mov byte [termios_new + 17], 0
    
    mov rax, 16
    xor rdi, rdi
    mov rsi, 0x5402
    mov rdx, termios_new
    syscall
    
    mov byte [show_lines], 1
    mov byte [line_offset], 4
    mov word [current_line], 1
    
    mov rax, 1
    mov rdi, 1
    mov rsi, clear_screen
    mov rdx, 7
    syscall
    
    mov rax, 1
    mov rdi, 1
    mov rsi, scroll_region
    mov rdx, 7
    syscall
    
    call draw_line_num
    
    mov rax, 1
    mov rdi, 1
    mov rsi, status_bar
    mov rdx, 87
    syscall
    
    mov byte [cursor_x], 5
    mov byte [cursor_y], 1
    
    mov rax, 1
    mov rdi, 1
    mov rsi, color_white
    mov rdx, 7
    syscall

main_loop:
    call update_cursor
    
    mov rax, 0
    mov rdi, 0
    mov rsi, char
    mov rdx, 1
    syscall
    
    test rax, rax
    jle main_loop
    
    movzx rax, byte [char]
    
    cmp al, 17
    je quit
    
    cmp al, 19
    je save
    
    cmp al, 12
    je toggle_lines
    
    cmp al, 11
    je cut_line
    
    cmp al, 3
    je quit
    
    cmp al, 127
    je backspace
    
    cmp al, 10
    je enter
    
    cmp al, 27
    je escape
    
    cmp al, 32
    jl main_loop
    
    cmp al, 'A'
    jl .write_char
    cmp al, 'Z'
    jg .write_char
    add al, 32
    mov [char], al
    
.write_char:
    cmp byte [cursor_x], 80
    jge main_loop
    
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    
    movzx rbx, word [buf_pos]
    cmp rbx, 4095
    jge main_loop
    
    mov al, [char]
    mov [buffer + rbx], al
    inc word [buf_pos]
    inc byte [cursor_x]
    jmp main_loop

backspace:
    movzx rax, byte [line_offset]
    inc rax
    cmp byte [cursor_x], al
    jle main_loop
    
    dec byte [cursor_x]
    call update_cursor
    
    mov byte [char], ' '
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    
    movzx rbx, word [buf_pos]
    test rbx, rbx
    jz main_loop
    dec word [buf_pos]
    jmp main_loop

enter:
    movzx rbx, word [buf_pos]
    cmp rbx, 4095
    jge main_loop
    
    mov byte [buffer + rbx], 10
    inc word [buf_pos]
    
    cmp byte [cursor_y], 23
    jge .scroll
    
    inc byte [cursor_y]
    inc word [current_line]
    movzx rax, byte [line_offset]
    inc rax
    mov [cursor_x], al
    call draw_line_num
    jmp main_loop
    
.scroll:
    mov byte [char], 10
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    
    inc word [current_line]
    movzx rax, byte [line_offset]
    inc rax
    mov [cursor_x], al
    call draw_line_num
    jmp main_loop

cut_line:
    movzx rbx, word [buf_pos]
    test rbx, rbx
    jz main_loop
    
    xor rcx, rcx
    mov r8w, 1
    
.find_line_start:
    cmp rcx, rbx
    jge .found_start
    
    movzx rax, byte [buffer + rcx]
    cmp al, 10
    jne .not_newline_start
    inc r8w
    cmp r8w, word [current_line]
    je .found_start_after_nl
.not_newline_start:
    inc rcx
    jmp .find_line_start
    
.found_start_after_nl:
    inc rcx
    
.found_start:
    mov r9, rcx
    
.find_line_end:
    cmp rcx, rbx
    jge .found_end
    
    movzx rax, byte [buffer + rcx]
    cmp al, 10
    je .found_end_with_nl
    inc rcx
    jmp .find_line_end
    
.found_end_with_nl:
    inc rcx
    
.found_end:
    mov r10, rcx
    
    sub r10, r9
    jz .cut_done
    
    mov rsi, rcx
    mov rdi, r9
    
.shift_loop:
    cmp rsi, rbx
    jge .shift_done
    
    mov al, [buffer + rsi]
    mov [buffer + rdi], al
    inc rsi
    inc rdi
    jmp .shift_loop
    
.shift_done:
    sub word [buf_pos], r10w
    
.cut_done:
    mov rax, 1
    mov rdi, 1
    mov rsi, clear_screen
    mov rdx, 7
    syscall
    
    mov rax, 1
    mov rdi, 1
    mov rsi, scroll_region
    mov rdx, 7
    syscall
    
    mov word [current_line], 1
    mov byte [cursor_y], 1
    movzx rax, byte [line_offset]
    inc rax
    mov [cursor_x], al
    
    xor rcx, rcx
    movzx rbx, word [buf_pos]
    
.redraw_loop:
    cmp rcx, rbx
    jge .redraw_done
    
    movzx rax, byte [buffer + rcx]
    
    cmp al, 10
    je .newline
    
    mov [char], al
    push rcx
    push rbx
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    pop rbx
    pop rcx
    inc rcx
    jmp .redraw_loop
    
.newline:
    mov byte [char], 10
    push rcx
    push rbx
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    pop rbx
    pop rcx
    inc rcx
    inc word [current_line]
    call draw_line_num
    jmp .redraw_loop
    
.redraw_done:
    mov rax, 1
    mov rdi, 1
    mov rsi, status_bar
    mov rdx, 87
    syscall
    
    mov rax, 1
    mov rdi, 1
    mov rsi, color_white
    mov rdx, 7
    syscall
    jmp main_loop

escape:
    mov rax, 0
    mov rdi, 0
    mov rsi, char
    mov rdx, 1
    syscall
    
    test rax, rax
    jle main_loop
    
    movzx rax, byte [char]
    cmp al, '['
    jne main_loop
    
    mov rax, 0
    mov rdi, 0
    mov rsi, char
    mov rdx, 1
    syscall
    
    test rax, rax
    jle main_loop
    
    movzx rax, byte [char]
    
    cmp al, 'A'
    je .up
    cmp al, 'B'
    je .down
    cmp al, 'C'
    je .right
    cmp al, 'D'
    jne main_loop
    
.left:
    movzx rax, byte [line_offset]
    inc rax
    cmp byte [cursor_x], al
    jle main_loop
    dec byte [cursor_x]
    jmp main_loop

.up:
    cmp byte [cursor_y], 1
    jle main_loop
    dec byte [cursor_y]
    cmp word [current_line], 1
    jle main_loop
    dec word [current_line]
    call draw_line_num
    jmp main_loop

.down:
    cmp byte [cursor_y], 23
    jge main_loop
    inc byte [cursor_y]
    inc word [current_line]
    call draw_line_num
    jmp main_loop

.right:
    cmp byte [cursor_x], 80
    jge main_loop
    inc byte [cursor_x]
    jmp main_loop

toggle_lines:
    xor byte [show_lines], 1
    
    cmp byte [show_lines], 1
    je .show
    
    mov byte [line_offset], 0
    cmp byte [cursor_x], 5
    jl .do_redraw
    sub byte [cursor_x], 4
    jmp .do_redraw
    
.show:
    mov byte [line_offset], 4
    add byte [cursor_x], 4
    
.do_redraw:
    mov rax, 1
    mov rdi, 1
    mov rsi, clear_screen
    mov rdx, 7
    syscall
    
    mov rax, 1
    mov rdi, 1
    mov rsi, scroll_region
    mov rdx, 7
    syscall
    
    mov word [current_line], 1
    mov byte [cursor_y], 1
    
    xor rcx, rcx
    movzx rbx, word [buf_pos]
    
.redraw_loop:
    cmp rcx, rbx
    jge .redraw_done
    
    movzx rax, byte [buffer + rcx]
    
    cmp al, 10
    je .newline
    
    mov [char], al
    push rcx
    push rbx
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    pop rbx
    pop rcx
    inc rcx
    jmp .redraw_loop
    
.newline:
    mov byte [char], 10
    push rcx
    push rbx
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    pop rbx
    pop rcx
    inc rcx
    inc word [current_line]
    call draw_line_num
    jmp .redraw_loop
    
.redraw_done:
    mov rax, 1
    mov rdi, 1
    mov rsi, status_bar
    mov rdx, 87
    syscall
    
    mov rax, 1
    mov rdi, 1
    mov rsi, color_white
    mov rdx, 7
    syscall
    jmp main_loop

draw_line_num:
    cmp byte [show_lines], 0
    je .skip
    
    push rax
    push rbx
    push rcx
    push rdx
    
    mov byte [char], 27
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    
    mov byte [char], '['
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    
    movzx rax, byte [cursor_y]
    call print_num
    
    mov byte [char], ';'
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    
    mov byte [char], '1'
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    
    mov byte [char], 'H'
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    
    mov rax, 1
    mov rdi, 1
    mov rsi, color_gray
    mov rdx, 11
    syscall
    
    movzx rax, word [current_line]
    call print_num
    
    mov byte [char], ' '
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    
    mov byte [char], '|'
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    
    mov byte [char], ' '
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    
    mov rax, 1
    mov rdi, 1
    mov rsi, color_white
    mov rdx, 7
    syscall
    
    pop rdx
    pop rcx
    pop rbx
    pop rax
.skip:
    ret

save:
    mov rax, 1
    mov rdi, 1
    mov rsi, reset_scroll
    mov rdx, 3
    syscall
    
    mov rax, 1
    mov rdi, 1
    mov rsi, prompt_save
    mov rdx, 30
    syscall
    
    mov qword [fname_len], 0
    
.read_loop:
    mov rax, 0
    mov rdi, 0
    mov rsi, char
    mov rdx, 1
    syscall
    
    test rax, rax
    jle .read_loop
    
    movzx rax, byte [char]
    
    cmp al, 10
    je .do_save
    
    cmp al, 127
    je .backspace_fname
    
    cmp al, 3
    je .cancel
    
    cmp al, 27
    je .cancel
    
    cmp al, 32
    jl .read_loop
    
    cmp al, 'A'
    jl .write_fname
    cmp al, 'Z'
    jg .write_fname
    add al, 32
    mov [char], al
    
.write_fname:
    mov r8, [fname_len]
    cmp r8, 255
    jge .read_loop
    
    mov [filename + r8], al
    inc qword [fname_len]
    
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    jmp .read_loop

.backspace_fname:
    cmp qword [fname_len], 0
    je .read_loop
    
    dec qword [fname_len]
    
    mov byte [char], 8
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    
    mov byte [char], ' '
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    
    mov byte [char], 8
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    jmp .read_loop

.do_save:
    cmp qword [fname_len], 0
    je .cancel
    
    mov r8, [fname_len]
    mov byte [filename + r8], 0
    
    mov rax, 2
    mov rdi, filename
    mov rsi, 0x241
    mov rdx, 0x1B6
    syscall
    
    cmp rax, 0
    jl .cancel
    
    mov r15, rax
    
    mov rax, 1
    mov rdi, r15
    mov rsi, buffer
    movzx rdx, word [buf_pos]
    syscall
    
    mov rax, 3
    mov rdi, r15
    syscall
    
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_saved
    mov rdx, 28
    syscall
    
    mov rax, 0
    mov rdi, 0
    mov rsi, char
    mov rdx, 1
    syscall

.cancel:
    mov rax, 1
    mov rdi, 1
    mov rsi, clear_screen
    mov rdx, 7
    syscall
    
    mov rax, 1
    mov rdi, 1
    mov rsi, scroll_region
    mov rdx, 7
    syscall
    
    call draw_line_num
    
    mov rax, 1
    mov rdi, 1
    mov rsi, status_bar
    mov rdx, 87
    syscall
    
    mov rax, 1
    mov rdi, 1
    mov rsi, color_white
    mov rdx, 7
    syscall
    jmp main_loop

update_cursor:
    mov byte [char], 27
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    
    mov byte [char], '['
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    
    movzx rax, byte [cursor_y]
    call print_num
    
    mov byte [char], ';'
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    
    movzx rax, byte [cursor_x]
    call print_num
    
    mov byte [char], 'H'
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    ret

print_num:
    mov rbx, 10
    xor rcx, rcx
.div:
    xor rdx, rdx
    div rbx
    push rdx
    inc rcx
    test rax, rax
    jnz .div
.pr:
    pop rax
    add al, '0'
    mov [char], al
    push rcx
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    pop rcx
    loop .pr
    ret

quit:
    mov rax, 16
    xor rdi, rdi
    mov rsi, 0x5402
    mov rdx, termios_orig
    syscall
    
    mov rax, 1
    mov rdi, 1
    mov rsi, reset_scroll
    mov rdx, 3
    syscall
    
    mov byte [char], 27
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    
    mov byte [char], '['
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    
    mov byte [char], '0'
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    
    mov byte [char], 'm'
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    
    mov rax, 1
    mov rdi, 1
    mov rsi, clear_screen
    mov rdx, 7
    syscall
    
    mov byte [char], 27
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    
    mov byte [char], '['
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    
    mov byte [char], '?'
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    
    mov byte [char], '2'
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    
    mov byte [char], '5'
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    
    mov byte [char], 'l'
    mov rax, 1
    mov rdi, 1
    mov rsi, char
    mov rdx, 1
    syscall
    
    mov rax, 60
    xor rdi, rdi
    syscall
