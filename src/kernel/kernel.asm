; kernel.asm
[org 0x7E00]
bits 16

%define ENDL 0x0D, 0x0A 

jmp  start
nop

;fat headers

bdb_oem:                    db 'MSWIN4.1'
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_clusters:   db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0E0h
bdb_total_sectors:          dw 2880
bdb_media_descriptor_type:  db 0F0h
bdb_sectors_per_fat:        dw 9
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

; extended boot records

ebr_drive_number:           db 0
                            db 0
ebr_signature:              db 29h
ebr_volume_id:              db 12h, 34h, 56h, 78h
ebr_volume_label:           db 'HUMMOS     '
ebr_system_id:              db 'FAT12   '

; go straight to create logo
start:
    jmp create_logo

compare:
.comp_loop:
    mov al, [si]
    mov bl, [di]

    cmp al, bl
    jne .comp_not_equal

    cmp al, 0
    je .comp_equal

    inc si
    inc di
    jmp .comp_loop

.comp_not_equal:
    mov ax, 1
    ret

.comp_equal:
    xor ax, ax
    ret

puts: 
    ; save registers in stack
    push si
    push ax

.loop:
    lodsb ; load next character in al
    or al, al ; verify if next character is null
    jz .done ;conitional jump
    
    cmp al, 0x0A
    je new_line

    ;print to screen using BIOS interrupt and print whatever is in al
    mov ah, 0x0e
    mov bh, 0
    int 0x10

    jmp .loop ;repeat the loop again for the next character

.done:
    ;remove registers from stack in opposite order
    pop ax
    pop si
    ret

create_logo:
    mov si, hummus_logo
    call puts
    jmp main

main: ;main function
    ; clear these segments
    mov ax, 0
    mov ds, ax
    mov es, ax

    ; setup stack
    mov ss, ax ; stack segment starts using adresses from 0x0000
    mov sp, 0x7C00 ; stack starts at the end of the boot sector

    mov si, msg_hello
    call puts

    mov si, prompt
    call puts

keyboard_input:
    mov ah, 0x00
    int 0x16        ; AL = typed character
    mov [last_key], al

    cmp al, 0x0D    ; Enter?
    je cmd_parse

    cmp al, 0x08    ; Backspace?
    je .backspace_input

    cmp ah, 0x53   ; Del
    je .backspace_input

    cmp ah, 0x4B    ; Left arrow pressed?
    je .left_arrow_pressed

    cmp ah, 0x4D    ; Right arrow pressed?
    je .right_arrow_pressed

    cmp ah, 0x48     ; up arrow
    je keyboard_input

    cmp ah, 0x50     ; down arrow
    je keyboard_input

    cmp byte [cmd_index], 31
    jae keyboard_input

    push ax
    xor al, al
    xor cx, cx          ; CX = length counter
    xor bx, bx          ; BX = index

    call .count_index

    cmp byte [cmd_index], cl
    jb .move_up

    pop ax

    mov bl, [cmd_index]
    mov [cmd + bx], al
    inc byte [cmd_index]

    mov ah, 0x0E
    int 0x10

    jmp keyboard_input

.move_up:
    cmp cl, 31
    je keyboard_input
    
    xor bx, bx
    xor dx, dx
    pop ax

    mov bl, cl

.move_up_loop:
    mov dl, [cmd + bx]
    mov byte [cmd + bx + 1], dl
    dec bx

    cmp bl, byte [cmd_index]
    jb .redraw

    cmp bl, 0
    je .special_redraw

    jmp .move_up_loop

.special_redraw:
    mov dl, [cmd + bx]
    mov byte [cmd + bx + 1], dl

.redraw:
    mov ah, 0x03
    mov bh, 0
    int 0x10

    mov ah, 0x02
    mov bh, 0
    mov dl, 0
    int 0x10

    mov cx, 79

.clear_loop:
    mov ah, 0x0E
    mov al, ' '
    int 0x10
    loop .clear_loop

    mov ah, 0x02
    mov bh, 0
    mov dl, 0
    int 0x10

    mov si, prompt
    call puts

    xor bx, bx

.print_loop:
    mov al, [cmd + bx]

    cmp al, 0
    je .return_loop

    mov ah, 0x0E
    int 0x10

    inc bx

    jmp .print_loop


.return_loop:
    mov ah, 0x0E
    mov al, 0x08          ; move cursor left
    int 0x10
    dec bl
    cmp bl, [cmd_index]
    je .yet_another_return_function
    jmp .return_loop

.yet_another_return_function:
    pop ax
    mov al, [last_key]
    mov ah, 0x0E
    int 0x10             ; print character / move visually right

    mov bl, [cmd_index]
    mov [cmd + bx], al
    inc byte [cmd_index]

    jmp keyboard_input


.count_index:
    mov al, [cmd + bx]
    cmp al, 0
    je .done

    inc cx
    inc bx
    jmp .count_index

.done:
    ret

.backspace_input:
    cmp byte [cmd_index], 0
    je keyboard_input     ; go back to keyboard_input if starting

    dec byte [cmd_index]
    xor bx,bx
    mov bl, [cmd_index]

    mov ah, 0x0E
    mov al, 0x08          ; move cursor left
    int 0x10

    xor cx,cx
    mov cx, 1

.backspace_loop:
    mov dl, [cmd + bx + 1]
    mov byte [cmd + bx], dl

    mov ah, 0x0E
    mov al, dl
    int 0x10
    
    cmp dl, 0
    je .move_back
    
    inc bx
    inc cx
    jmp .backspace_loop
    
.move_back:
    mov ah, 0x0E
    mov al, 0x08          ; move cursor left
    int 0x10

    loop .move_back

    jmp keyboard_input

.left_arrow_pressed:
    cmp byte [cmd_index], 0
    je keyboard_input     ; go back to keyboard_input if starting

    mov ah, 0x0E
    mov al, 0x08          ; move cursor left
    int 0x10

    dec byte [cmd_index]

    jmp keyboard_input


.right_arrow_pressed:
    cmp byte [cmd_index], 32
    jae keyboard_input

    xor bh, bh
    mov bl, [cmd_index]

    mov al, [cmd + bx]   ; load existing character

    cmp al, 0
    je keyboard_input    ; nothing there

    mov ah, 0x0E
    int 0x10             ; print character / move visually right

    inc byte [cmd_index]

    jmp keyboard_input

cmd_parse:
    xor al, al
    xor cx, cx          ; CX = length counter
    xor bx, bx          ; BX = index

    call .count_index

    mov bx, cx
    mov byte [cmd + bx], 0

    mov si, cmd
    mov di, cmd_help
    call compare
    je help_cmd ;jmp if equal

    mov si, cmd
    mov di, cmd_clear
    call compare
    je clear_cmd ;jmp if equal

    mov si, cmd
    mov di, cmd_quit
    call compare
    je quit_cmd ;jmp if equal

    mov si, cmd
    mov di, cmd_reboot
    call compare
    je reboot_cmd ;jmp if equal

    mov si, cmd
    mov di, cmd_sps
    call compare
    je sps_cmd ;jmp if equal

    mov si, cmd
    mov di, cmd_time
    call compare
    je time_cmd ;jmp if equal

    mov si, cmd
    mov di, cmd_mr
    call compare
    je mr_cmd ;jmp if equal

    mov si, cmd
    mov di, cmd_info
    call compare
    je info_cmd ;jmp if equal

    mov si, cmd
    mov di, cmd_bits
    call compare
    je bits_cmd ;jmp if equal

    mov si, cmd
    mov di, cmd_dvd
    call compare
    je dvd_cmd ;jmp if equal

    mov si, cmd
    mov di, cmd_chud
    call compare
    je secret_chud_cmd ;jmp if equal

    mov si, cmd
    mov di, cmd_unicorn
    call compare
    je unicorn_cmd ;jmp if equal

    mov si, cmd
    mov di, cmd_lion
    call compare
    je lion_cmd ;jmp if equal

    mov si, cmd
    mov di, cmd_error
    call compare
    je error_cmd ;jmp if equal

    mov si, cmd
    mov di, cmd_pong
    call compare
    je pong_cmd ;jmp if equal

    mov si, cmd
    mov di, cmd_credits
    call compare
    je credits_cmd ;jmp if equal

    mov si, cmd
    mov di, cmd_snake
    call compare
    je snake_cmd ;jmp if equal

    mov si, cmd
    mov di, cmd_snake_impossible
    call compare
    je snake_cmd_impossible ;jmp if equal

    mov si, cmd
    mov di, cmd_hoi4
    call compare
    je hoi4_cmd ;jmp if equal

    mov si, cmd
    mov di, cmd_2026
    call compare
    je class_of_2026_cmd ;jmp if equal


    mov byte [cmd_index], 0 

    mov ah, 0x0E

    mov al, 0x0D    
    int 0x10

    mov al, 0x0A
    int 0x10

    mov si, msg_error
    call puts

    jmp create_new_line

.count_index:
    mov al, [cmd + bx]
    cmp al, 0
    je .done

    inc cx
    inc bx
    jmp .count_index

.done:
    ret

help_cmd:
    mov ah, 0x0E

    mov al, 0x0D    
    int 0x10

    mov al, 0x0A
    int 0x10

    mov si, msg_help
    call puts

    mov byte [cmd_index], 0 
    jmp create_new_line

sps_cmd:
    mov ah, 0x0E

    mov al, 0x0D    
    int 0x10

    mov al, 0x0A
    int 0x10

    mov si, sps_logo
    call puts

    mov byte [cmd_index], 0 
    jmp create_new_line


class_of_2026_cmd:
    mov ah, 0x0E

    mov al, 0x0D    
    int 0x10

    mov al, 0x0A
    int 0x10

    mov si, class_of_2026
    call puts

    mov byte [cmd_index], 0 
    jmp create_new_line

hoi4_cmd:
    mov ah, 0x0E

    mov al, 0x0D    
    int 0x10

    mov al, 0x0A
    int 0x10

    mov si, hoi4_troops
    call puts

    mov byte [cmd_index], 0 
    jmp create_new_line

credits_cmd:
    mov ah, 0x0E

    mov al, 0x0D    
    int 0x10

    mov al, 0x0A
    int 0x10

    mov si, msg_credits
    call puts

    mov byte [cmd_index], 0 
    jmp create_new_line

secret_chud_cmd:
    mov ah, 0x0E

    mov al, 0x0D    
    int 0x10

    mov al, 0x0A
    int 0x10

    mov si, chud_logo
    call puts

    mov byte [cmd_index], 0 
    jmp create_new_line

unicorn_cmd:
    mov byte [cmd_index], 0
    mov edi, cmd   ; destination address
    mov ecx, 32       ; number of bytes
    xor eax, eax      ; AL = 0
    rep stosb         ; fill ECX bytes at EDI with AL
    
    mov word [art_x], 0
    mov word [art_y], 0
    mov word [logo_index],0

    call .main
    mov byte [cmd_index], 0
    jmp clear_cmd

.main:
    mov ax, 0x0003
    int 0x10
    
    mov ax, 0xB800
    mov es, ax

    call clear_screen

.main_loop:

    push ax
    push cx
    push dx
    push bx

    xor di, di
    mov ax, [art_y]
    mov dx, 80
    mul dx

    shl ax, 1
    mov di, ax
    mov bx, [art_x]
    shl bx, 1
    add di, bx

    pop bx
    pop dx
    pop cx
    pop ax

    mov bx, [logo_index]
    mov al, [unicorn_logo + bx]

    cmp al, 0x0A
    je .new_line

    cmp al, 0
    je .wait

    mov byte [es:di], al
    mov byte [es:di+1], 0x71

    inc word [art_x]
    inc word [logo_index]
    jmp .main_loop

.new_line:
    mov byte [art_x], 0
    inc [art_y]
    inc word [logo_index]
    jmp .main_loop

.wait:
    mov ah, 0x01
    int 0x16
    jnz .done
    jmp .wait

.done:
    ret

lion_cmd:
    mov byte [cmd_index], 0
    mov edi, cmd   ; destination address
    mov ecx, 32       ; number of bytes
    xor eax, eax      ; AL = 0
    rep stosb         ; fill ECX bytes at EDI with AL
    
    mov word [art_x], 0
    mov word [art_y], 0
    mov word [logo_index],0

    call .main
    mov byte [cmd_index], 0
    jmp clear_cmd

.main:
    mov ax, 0x0003
    int 0x10

    mov ax, 0xB800
    mov es, ax

    call clear_screen

.main_loop:

    push ax
    push cx
    push dx
    push bx

    xor di, di
    mov ax, [art_y]
    mov dx, 80
    mul dx

    shl ax, 1
    mov di, ax
    mov bx, [art_x]
    shl bx, 1
    add di, bx

    pop bx
    pop dx
    pop cx
    pop ax

    mov bx, [logo_index]
    mov al, [lion_logo + bx]

    cmp al, 0x0A
    je .new_line

    cmp al, 0
    je .wait

    mov byte [es:di], al
    mov byte [es:di+1], 0x74

    inc word [art_x]
    inc word [logo_index]
    jmp .main_loop

.new_line:
    mov word [art_x], 0
    inc word [art_y]
    inc word [logo_index]
    jmp .main_loop

.wait:
    mov ah, 0x01
    int 0x16
    jnz .done
    jmp .wait

.done:
    ret

error_cmd:
    mov byte [cmd_index], 0
    mov edi, cmd   ; destination address
    mov ecx, 32       ; number of bytes
    xor eax, eax      ; AL = 0
    rep stosb         ; fill ECX bytes at EDI with AL
    
    mov word [art_x], 0
    mov word [art_y], 0
    mov word [logo_index],0

    call .main
    mov byte [cmd_index], 0
    jmp clear_cmd

.main:
    mov ax, 0x0003
    int 0x10

    mov ax, 0xB800
    mov es, ax

    call clear_screen

.main_loop:

    push ax
    push cx
    push dx
    push bx

    xor di, di
    mov ax, [art_y]
    mov dx, 80
    mul dx

    shl ax, 1
    mov di, ax
    mov bx, [art_x]
    shl bx, 1
    add di, bx

    pop bx
    pop dx
    pop cx
    pop ax

    mov bx, [logo_index]
    mov al, [error_screen + bx]

    cmp al, 0x71
    je .change_gray

    cmp al, 0x1F
    je .change_blue

    cmp al, 0x0A
    je .new_line

    cmp al, 0
    je .wait

    mov byte [es:di], al
    mov al, byte [error_color]
    mov byte [es:di+1], al

    inc word [art_x]
    inc word [logo_index]
    jmp .main_loop

.change_gray:
    mov byte [error_color],0x71
    inc word [logo_index]
    jmp .main_loop

.change_blue: 
    inc word [logo_index]
    mov byte [error_color], 0x1F
    jmp .main_loop

.new_line:
    mov byte [art_x], 0
    inc [art_y]
    inc word [logo_index]
    jmp .main_loop

.wait:
    mov ah, 0x01
    int 0x16
    jnz .done

    push ds
    mov ax, 0x0040
    mov ds, ax

    mov al, [0x0017]

    pop ds

    test al, 0x04      ; CTRL
    jz .wait

    test al, 0x08      ; ALT
    jz .wait

    ; CTRL + ALT is pressed here
    jmp .pressed

.pressed:
    jmp reboot_cmd

.done:
    ret

bits_cmd:
    mov si, bits_conversion
    call puts

    mov byte [cmd_index], 0 
    jmp create_new_line

clear_cmd:
    mov ax, 0x0003
    int 0x10        ; set text mode 80x25, clears screen
    xor si, si
    mov byte [cmd_index], 0
    mov edi, cmd   ; destination address
    mov ecx, 32       ; number of bytes
    xor eax, eax      ; AL = 0
    rep stosb         ; fill ECX bytes at EDI with AL
    jmp main

quit_cmd:
    mov ax, 0x5307
    mov bx, 0x0001
    mov cx, 0x0003
    int 0x15

reboot_cmd:
    jmp 0FFFFh:0

time_cmd:
    ; call time function 
    ; hours stored in ch
    ; minutes stored in cl
    ; seconds stored in dh
    mov ah, 02h
    int 1Ah

    mov si, time_is
    call puts

    mov al, ch
    call .convert_time

    mov al, ':'
    call .print_time

    mov al, cl
    call .convert_time

    mov al, ':'
    call .print_time

    mov al, dh
    call .convert_time

    mov byte [cmd_index], 0
    jmp create_new_line

.convert_time:
    ; ex: 0x14 -> 14
    push ax

    ;extract first digit
    mov ah, al
    shr ah, 4
    add ah, '0'

    mov al, ah
    call .print_time

    pop ax

    ;extract second digit digit
    and al, 0Fh
    add al, '0'
    call .print_time

    ret

.print_time:
    mov ah, 0x0e
    mov bh, 0
    int 0x10
    ret

    jmp main

delay:
    mov cx, 0FFFFh
.loop:
    loop .loop
    ret

wait_200ms:
    push es

    mov ax, 0x0040
    mov es, ax

    mov bx, [es:0x006C]
    add bx, 4            ; ~0.22 seconds

.wait:
    mov ax, [es:0x006C]
    cmp ax, bx
    jb .wait

    pop es
    ret

wait_50ms:
    push es

    mov ax, 0x0040
    mov es, ax

    mov bx, [es:0x006C]
    add bx, 1        

.wait:
    mov ax, [es:0x006C]
    cmp ax, bx
    jb .wait

    pop es
    ret

wait_25ms:
    push ax
    push bx
    push dx

    ; latch PIT channel 0
    mov al, 0
    out 0x43, al

    ; read current counter
    in al, 0x40
    mov bl, al
    in al, 0x40
    mov bh, al

.wait:
    mov al, 0
    out 0x43, al

    in al, 0x40
    mov dl, al
    in al, 0x40
    mov dh, al

    ; elapsed = start - current
    mov ax, bx
    sub ax, dx

    cmp ax, 29829
    jb .wait

    pop dx
    pop bx
    pop ax
    ret

clear_screen:
    xor di, di
    mov cx, 2000

.clear_loop:
    mov byte [es:di], ' '
    mov byte [es:di+1], 0x07

    add di, 2
    loop .clear_loop
    ret

clear_pong:
    mov ax, 0A000h
    mov es, ax

    xor di, di        ; start at 0
    mov cx, 64000     ; total pixels
    mov al, 0         ; black color

    rep stosb         ; fill screen
    ret

pong_cmd:
    mov byte [cmd_index], 0
    mov edi, cmd   ; destination address
    mov ecx, 32       ; number of bytes
    xor eax, eax      ; AL = 0
    rep stosb         ; fill ECX bytes at EDI with AL

    mov word [ball_x], 50
    mov word [ball_y], 50

    mov word [ball_vel_x], 5
    mov word [ball_vel_y], 5

    mov word [left_paddle_y], 0
    mov word [left_paddle_x], 0

    mov word [right_paddle_y], 0
    mov word [right_paddle_x], 315   

.main: 
    mov ax, 0013h
    int 10h
    mov ax, 0A000h
    mov es, ax
    
    mov byte [pong_color], 15
    mov si, [left_paddle_x]
    mov ax, [left_paddle_y]
    call .draw_paddle

    mov si, [right_paddle_x]
    mov ax, [right_paddle_y]
    
    call .draw_paddle

    mov byte [pong_color], 2
    xor ax, ax
    xor si, si
    push dx
    mov si, word [ball_x]
    add si, [ball_vel_x]    
    mov [ball_x], si  
    mov ax, word [ball_y] 
    add ax, [ball_vel_y]           
    mov [ball_y], ax
    call .draw_ball

    xor ah, ah
    int 16h

.loop:
    mov byte [pong_color], 0
    mov si, [left_paddle_x]
    mov ax, [left_paddle_y]
    call .draw_paddle

    mov si, [right_paddle_x]
    mov ax, [right_paddle_y]
    call .draw_paddle

    mov byte [pong_color], 0
    xor ax, ax
    xor si, si
    push dx
    mov si, word [ball_x] 
    mov [ball_x], si  
    mov ax, word [ball_y]      
    mov [ball_y], ax
    call .draw_ball

    mov ah, 01h
    int 16h
    jz .no_input

    mov ah, 00h
    int 16h

    cmp ah, 50h
    je .move_right_down

    cmp ah, 48h
    je .move_right_up

.second:

    cmp al, 's'
    je .move_left_down

    cmp al, 'w'
    je .move_left_up

    jmp .no_input

.move_right_up:
    cmp word [right_paddle_y],0
    je .second
    sub word [right_paddle_y], 10
    jmp .second

.move_right_down:
    cmp word [right_paddle_y],170
    je .second
    add word [right_paddle_y], 10
    jmp .second

.move_left_up:
    cmp word [left_paddle_y],0
    je .no_input
    sub word [left_paddle_y], 10
    jmp .no_input

.move_left_down:
    cmp word [left_paddle_y],170
    je .no_input
    add word [left_paddle_y], 10
    jmp .no_input

.no_input:

    mov byte [pong_color], 15
    mov si, [left_paddle_x]
    mov ax, [left_paddle_y]
    call .draw_paddle

    mov si, [right_paddle_x]
    mov ax, [right_paddle_y]
    
    call .draw_paddle

    cmp [ball_y], 195
    je .reverse_y

    cmp [ball_y], 0
    je .reverse_y

.loop_one:   

    cmp [ball_x], 310
    je .check_x_right

    cmp [ball_x], 5
    je .check_x_left

.loop_two:
    mov byte [pong_color], 2
    xor ax, ax
    xor si, si
    push dx
    mov si, word [ball_x]
    add si, [ball_vel_x]    
    mov [ball_x], si  
    mov ax, word [ball_y] 
    add ax, [ball_vel_y]           
    mov [ball_y], ax
    call .draw_ball

    call wait_50ms

    jmp .loop

.reverse_y:
    neg word [ball_vel_y]
    jmp .loop_one

.check_x_right:
    xor ax, ax
    mov ax, [ball_y]

    ; ball_y < paddle_y ?
    cmp ax, [right_paddle_y]
    jl .game_over

    ; paddle_y + 30
    mov bx, [right_paddle_y]
    add bx, 30

    ; ball_y > paddle_bottom ?
    cmp ax, bx
    jg .game_over

    ; collision happened
    jmp .bounce

.bounce:
    neg word [ball_vel_x]
    jmp .loop_two

.check_x_left:
    xor ax, ax
    mov ax, [ball_y]

    ; ball_y < paddle_y ?
    cmp ax, [left_paddle_y]
    jl .game_over

    ; paddle_y + 30
    mov bx, [left_paddle_y]
    add bx, 30

    ; ball_y > paddle_bottom ?
    cmp ax, bx
    jg .game_over

    ; collision happened
    jmp .bounce


.draw_ball:
    mov bx, ax
    mov dx, 5

.ball_row_loop:
    push dx
    xor dx, dx
    mov ax, bx
    mov di, 320
    mul di

    add ax, si
    mov di, ax

    mov cx, 5
    mov al, byte [pong_color]
    pop dx

.ball_col_loop:
    stosb
    loop .ball_col_loop

    inc bx
    dec dx
    jnz .ball_row_loop
    ret

.draw_paddle:

    mov bx, ax
    mov dx, 30

.row_loop:
    push dx
    mov ax, bx
    mov di, 320
    mul di

    add ax, si
    mov di, ax

    mov cx, 5
    mov al, byte [pong_color]
    pop dx

.col_loop:
    stosb
    loop .col_loop

    inc bx
    dec dx
    jnz .row_loop
    ret

.game_over:
    mov byte [pong_color], 2
    mov si, word [ball_x]
    add si, [ball_vel_x]    
    mov [ball_x], si  
    mov ax, word [ball_y] 
    add ax, [ball_vel_y]           
    mov [ball_y], ax
    call .draw_ball
    
.hold:
    mov ah, 0x00
    int 0x16        ; AL = typed character

    cmp al, 0x0D    ; Enter?
    je .key_pressed 
    jmp .hold

.key_pressed:
    mov byte [cmd_index], 0
    jmp clear_cmd

snake_clear_screen:
    xor di, di
    mov cx, 2000

.clear_loop:
    mov byte [es:di], 07h
    mov byte [es:di+1], 0x07

    add di, 2
    loop .clear_loop
    ret

snake_cmd:
    mov byte [cmd_index], 0
    mov edi, cmd   ; destination address
    mov ecx, 32       ; number of bytes
    xor eax, eax      ; AL = 0
    rep stosb         ; fill ECX bytes at EDI with AL

.main:
    mov ax, 0xB800
    mov es, ax

    mov bx,0
    call snake_clear_screen

    mov byte [snake_len], 5
    mov byte [snake_direction], 0
    
    mov byte [snake_x + 0], 4
    mov byte [snake_x + 1], 3
    mov byte [snake_x + 2], 2
    mov byte [snake_x + 3], 1

    mov byte [snake_y + 0], 10
    mov byte [snake_y + 1], 10
    mov byte [snake_y + 2], 10
    mov byte [snake_y + 3], 10

    call .spawn_food
    jmp .loop

.loop:
    call .keyboard_input
    call .move_snake
    call .check_collision
    call snake_clear_screen
    call .draw_screen
    call .draw_food
    call wait_50ms
    jmp .loop

.keyboard_input:
    mov ah, 01h
    int 16h
    jz .no_key

    mov ah, 00h
    int 16h

    cmp ah, 48h
    je .move_up

    cmp ah, 50h
    je .move_down

    cmp ah, 4Bh
    je .move_left

    cmp ah, 4Dh
    je .move_right

    ret

.move_up:
    cmp byte [snake_direction], 3
    je .ret
    mov byte [snake_direction], 2
    ret

.move_down:
    cmp byte [snake_direction], 2
    je .ret
    mov byte [snake_direction], 3
    ret

.move_right:
    cmp byte [snake_direction], 1
    je .ret
    mov byte [snake_direction], 0
    ret

.move_left:
    cmp byte [snake_direction], 0
    je .ret
    mov byte [snake_direction], 1
    ret

.no_key:
    ret

.ret:
    ret

.move_snake:
    mov cl, byte [snake_len]
    dec cx
    mov bx , cx

.move_snake_loop:
    mov al, [snake_x + bx - 1]
    mov [snake_x + bx], al
    mov al, [snake_y + bx - 1]
    mov [snake_y + bx], al
    dec bx
    loop .move_snake_loop
    
.move_head:
    cmp byte [snake_direction], 2
    je .head_up

    cmp byte [snake_direction], 3
    je .head_down

    cmp byte [snake_direction], 0
    je .head_right

    cmp byte [snake_direction], 1
    je .head_left

    ret

.head_up:
    dec byte [snake_y]
    jmp .check_apple_x

.head_down:
    inc byte [snake_y]
    jmp .check_apple_x

.head_left:
    dec byte [snake_x]
    jmp .check_apple_x

.head_right:
    inc byte [snake_x]
    jmp .check_apple_x

.check_apple_x:
    xor ax,ax
    mov al, byte [food_x]
    cmp byte [snake_x], al
    je .check_apple_y
    ret

.check_apple_y:
    xor ax,ax
    mov al, byte [food_y]
    cmp byte [snake_y], al
    je .spawn_food
    ret

.spawn_food:
    mov bl, [snake_len]

    ; copy last tail segment into new slot
    mov al, [snake_x + bx - 1]
    mov [snake_x + bx], al

    mov al, [snake_y + bx - 1]
    mov [snake_y + bx], al

    inc byte [snake_len]
    ;x
    ; get timer ticks
    mov ah, 00h
    int 1Ah

    mov ax, dx
    xor dx, dx

    mov bx, 80
    div bx

    ; remainder in DX
    mov [food_x], dl

    ;y
    mov ah, 00h
    int 1Ah

    mov ax, dx
    xor dx, dx

    mov bx, 25
    div bx

    mov [food_y], dl

    ret

.check_collision:
    cmp byte [snake_x], 80
    je .game_over

    cmp byte [snake_x], -1
    je .game_over

    cmp byte [snake_y], -1
    je .game_over

    cmp byte [snake_y], 25
    je .game_over

.snake_self_collision:
    xor bx, bx
    mov bl, 1

.check_loop:
    cmp bl, [snake_len]
    jae .done

    mov al, [snake_x + bx]
    cmp al, [snake_x]
    jne .next

    mov al, [snake_y + bx]
    cmp al, [snake_y]
    je .game_over

.next:
    inc bl
    jmp .check_loop

.done:
    ret

.draw_screen:
    mov cl, [snake_len]
    xor bx, bx
    xor dx, dx

.draw_screen_loop:
    xor ax, ax
    mov al, [snake_y+bx]
    mov dx, 80
    mul dx
    shl ax, 1

    mov di, ax
    xor ax, ax
    mov al, [snake_x+bx]
    shl ax, 1

    add di, ax

    mov byte [es:di], 'O'
    mov byte [es:di+1], 0x04

    inc bx

    loop .draw_screen_loop
    ret

.draw_food:

    xor ax, ax
    mov al, [food_y]

    mov bx, 80
    mul bx

    xor bx, bx
    mov bl, [food_x]

    add ax, bx
    shl ax, 1

    mov di, ax

    mov byte [es:di], 3 ; heart
    mov byte [es:di+1], 0x0A

    ret

.game_over:
    mov ax, 0xB800
    mov es, ax

    xor di, di

    ; center: row 11, col 30
    mov ax, 11
    mov dx, 80
    mul dx

    shl ax, 1
    mov di, ax

    mov ax, 32
    shl ax, 1
    add di, ax

    mov byte [es:di],     'Y'
    mov byte [es:di+1],   0x09
    mov byte [es:di+2],   'O'
    mov byte [es:di+3],   0x09
    mov byte [es:di+4],   'U'
    mov byte [es:di+5],   0x09
    mov byte [es:di+6],   'R'
    mov byte [es:di+7],   0x09
    mov byte [es:di+8],   ' '
    mov byte [es:di+9],   0x09
    mov byte [es:di+10],  'S'
    mov byte [es:di+11],  0x09
    mov byte [es:di+12],  'C'
    mov byte [es:di+13],  0x09
    mov byte [es:di+14],  'O'
    mov byte [es:di+15],  0x09
    mov byte [es:di+16],  'R'
    mov byte [es:di+17],  0x09
    mov byte [es:di+18],  'E'
    mov byte [es:di+19],  0x09
    mov byte [es:di+20],  ':'
    mov byte [es:di+21],  0x09
    mov byte [es:di+22],   ' '
    mov byte [es:di+23],  0x09

    mov ax, [snake_len]   ; number to print
    mov bx, 10
    xor cx, cx            ; digit count

.convert:
    xor dx, dx
    div bx            ; AX / 10 → AX=quotient, DX=remainder

    push dx           ; store digit
    inc cx

    cmp ax, 0
    jne .convert

.print:
    pop dx
    add dl, '0'
    mov [es:di+24], dl
    mov byte [es:di+25], 0x09
    add di, 2
    loop .print

.wait:
    mov ah, 0x00
    int 0x16        ; AL = typed character

    cmp al, 0x0D    ; Enter?
    je .leave
    jmp .wait

.leave:
    mov byte [cmd_index], 0
    jmp clear_cmd

snake_cmd_impossible:
    mov byte [cmd_index], 0
    mov edi, cmd   ; destination address
    mov ecx, 32       ; number of bytes
    xor eax, eax      ; AL = 0
    rep stosb         ; fill ECX bytes at EDI with AL

.main:
    mov ax, 0xB800
    mov es, ax

    mov bx,0
    call snake_clear_screen

    mov byte [snake_len], 5
    mov byte [snake_direction], 0
    
    mov byte [snake_x + 0], 4
    mov byte [snake_x + 1], 3
    mov byte [snake_x + 2], 2
    mov byte [snake_x + 3], 1

    mov byte [snake_y + 0], 10
    mov byte [snake_y + 1], 10
    mov byte [snake_y + 2], 10
    mov byte [snake_y + 3], 10

    call .spawn_food
    jmp .loop

.loop:
    call .keyboard_input
    call .move_snake
    call .check_collision
    call snake_clear_screen
    call .draw_screen
    call .draw_food
    call wait_25ms
    jmp .loop

.keyboard_input:
    mov ah, 01h
    int 16h
    jz .no_key

    mov ah, 00h
    int 16h

    cmp ah, 48h
    je .move_up

    cmp ah, 50h
    je .move_down

    cmp ah, 4Bh
    je .move_left

    cmp ah, 4Dh
    je .move_right

    ret

.move_up:
    cmp byte [snake_direction], 3
    je .ret
    mov byte [snake_direction], 2
    ret

.move_down:
    cmp byte [snake_direction], 2
    je .ret
    mov byte [snake_direction], 3
    ret

.move_right:
    cmp byte [snake_direction], 1
    je .ret
    mov byte [snake_direction], 0
    ret

.move_left:
    cmp byte [snake_direction], 0
    je .ret
    mov byte [snake_direction], 1
    ret

.no_key:
    ret

.ret:
    ret

.move_snake:
    mov cl, byte [snake_len]
    dec cx
    mov bx , cx

.move_snake_loop:
    mov al, [snake_x + bx - 1]
    mov [snake_x + bx], al
    mov al, [snake_y + bx - 1]
    mov [snake_y + bx], al
    dec bx
    loop .move_snake_loop
    
.move_head:
    cmp byte [snake_direction], 2
    je .head_up

    cmp byte [snake_direction], 3
    je .head_down

    cmp byte [snake_direction], 0
    je .head_right

    cmp byte [snake_direction], 1
    je .head_left

    ret

.head_up:
    dec byte [snake_y]
    jmp .check_apple_x

.head_down:
    inc byte [snake_y]
    jmp .check_apple_x

.head_left:
    dec byte [snake_x]
    jmp .check_apple_x

.head_right:
    inc byte [snake_x]
    jmp .check_apple_x

.check_apple_x:
    xor ax,ax
    mov al, byte [food_x]
    cmp byte [snake_x], al
    je .check_apple_y
    ret

.check_apple_y:
    xor ax,ax
    mov al, byte [food_y]
    cmp byte [snake_y], al
    je .spawn_food
    ret

.spawn_food:
    mov bl, [snake_len]

    ; copy last tail segment into new slot
    mov al, [snake_x + bx - 1]
    mov [snake_x + bx], al

    mov al, [snake_y + bx - 1]
    mov [snake_y + bx], al

    inc byte [snake_len]
    ;x
    ; get timer ticks
    mov ah, 00h
    int 1Ah

    mov ax, dx
    xor dx, dx

    mov bx, 80
    div bx

    ; remainder in DX
    mov [food_x], dl

    ;y
    mov ah, 00h
    int 1Ah

    mov ax, dx
    xor dx, dx

    mov bx, 25
    div bx

    mov [food_y], dl

    ret

.check_collision:
    cmp byte [snake_x], 80
    je .game_over

    cmp byte [snake_x], -1
    je .game_over

    cmp byte [snake_y], -1
    je .game_over

    cmp byte [snake_y], 25
    je .game_over

.snake_self_collision:
    xor bx, bx
    mov bl, 1

.check_loop:
    cmp bl, [snake_len]
    jae .done

    mov al, [snake_x + bx]
    cmp al, [snake_x]
    jne .next

    mov al, [snake_y + bx]
    cmp al, [snake_y]
    je .game_over

.next:
    inc bl
    jmp .check_loop

.done:
    ret

.draw_screen:
    mov cl, [snake_len]
    xor bx, bx
    xor dx, dx

.draw_screen_loop:
    xor ax, ax
    mov al, [snake_y+bx]
    mov dx, 80
    mul dx
    shl ax, 1

    mov di, ax
    xor ax, ax
    mov al, [snake_x+bx]
    shl ax, 1

    add di, ax

    mov byte [es:di], 'O'
    mov byte [es:di+1], 0x04

    inc bx

    loop .draw_screen_loop
    ret

.draw_food:

    xor ax, ax
    mov al, [food_y]

    mov bx, 80
    mul bx

    xor bx, bx
    mov bl, [food_x]

    add ax, bx
    shl ax, 1

    mov di, ax

    mov byte [es:di], 3 ; heart
    mov byte [es:di+1], 0x0A

    ret

.game_over:
    mov ax, 0xB800
    mov es, ax

    xor di, di

    ; center: row 11, col 30
    mov ax, 11
    mov dx, 80
    mul dx

    shl ax, 1
    mov di, ax

    mov ax, 32
    shl ax, 1
    add di, ax

    mov byte [es:di],     'Y'
    mov byte [es:di+1],   0x09
    mov byte [es:di+2],   'O'
    mov byte [es:di+3],   0x09
    mov byte [es:di+4],   'U'
    mov byte [es:di+5],   0x09
    mov byte [es:di+6],   'R'
    mov byte [es:di+7],   0x09
    mov byte [es:di+8],   ' '
    mov byte [es:di+9],   0x09
    mov byte [es:di+10],  'S'
    mov byte [es:di+11],  0x09
    mov byte [es:di+12],  'C'
    mov byte [es:di+13],  0x09
    mov byte [es:di+14],  'O'
    mov byte [es:di+15],  0x09
    mov byte [es:di+16],  'R'
    mov byte [es:di+17],  0x09
    mov byte [es:di+18],  'E'
    mov byte [es:di+19],  0x09
    mov byte [es:di+20],  ':'
    mov byte [es:di+21],  0x09
    mov byte [es:di+22],   ' '
    mov byte [es:di+23],  0x09

    mov ax, [snake_len]   ; number to print
    mov bx, 10
    xor cx, cx            ; digit count

.convert:
    xor dx, dx
    div bx            ; AX / 10 → AX=quotient, DX=remainder

    push dx           ; store digit
    inc cx

    cmp ax, 0
    jne .convert

.print:
    pop dx
    add dl, '0'
    mov [es:di+24], dl
    mov byte [es:di+25], 0x09
    add di, 2
    loop .print

.wait:
    mov ah, 0x00
    int 0x16        ; AL = typed character

    cmp al, 0x0D    ; Enter?
    je .leave
    jmp .wait


.leave:
    mov byte [cmd_index], 0
    jmp clear_cmd

dvd_cmd:
    mov byte [cmd_index], 0
    mov edi, cmd   ; destination address
    mov ecx, 32       ; number of bytes
    xor eax, eax      ; AL = 0
    rep stosb         ; fill ECX bytes at EDI with AL
    call .main
    mov byte [cmd_index], 0
    jmp clear_cmd

.main:
    mov ax, 0xB800
    mov es, ax

    mov bx,0
    call clear_screen
    jmp .main_loop


.main_loop:
    mov ah, 0x01
    int 0x16
    jnz .key_pressed 

    call clear_screen

    push ax
    push cx
    push dx
    push bx

    xor di, di
    mov ax, [y]
    mov dx, 80
    mul dx

    shl ax, 1
    mov di, ax
    mov bx, [x]
    shl bx, 1
    add di, bx

    pop bx
    pop dx
    pop cx
    pop ax

    mov byte [es:di], 'H'
    mov byte [es:di+1], 0x04
    mov byte [es:di+2], 'U'
    mov byte [es:di+3], 0x04
    mov byte [es:di+4], 'M'
    mov byte [es:di+5], 0x04
    mov byte [es:di+6], 'M'
    mov byte [es:di+7], 0x04
    mov byte [es:di+8], 'O'
    mov byte [es:di+9], 0x04
    mov byte [es:di+10], 'S'
    mov byte [es:di+11], 0x04

    mov ax, [x]
    add ax, [x_velocity]
    mov [x], ax 
    mov ax, [y]
    add ax, [y_velocity]
    mov [y], ax

    cmp word [y], 24
    je .change_y

    cmp word [y], 0
    je .change_y

    cmp word [x], 74
    je .change_x

    cmp word [x], 0
    je .change_x

    call wait_200ms

    jmp .main_loop

.change_y:
    neg word [y_velocity]
    call wait_200ms
    jmp .main_loop

.change_x:
    neg word [x_velocity]
    call wait_200ms
    jmp .main_loop

.key_pressed:
    ret

.halt:
    jmp .halt

mr_cmd:
    mov byte [cmd_index], 0
    mov edi, cmd   ; destination address
    mov ecx, 32       ; number of bytes
    xor eax, eax      ; AL = 0
    rep stosb         ; fill ECX bytes at EDI with AL
    call matrix_rain
    mov byte [cmd_index], 0
    jmp clear_cmd

matrix_rain:

    ;move into video memory
    mov ax, 0xB800
    mov es, ax

    ;bx=x ;cx=columns
    mov bx, 0
    mov cx, 80


.initalize_columns:
    ;move 0 into every col
    mov byte [cols + bx], 0
    inc bx
    loop .initalize_columns ;auto dec cx 

.main_loop:
 
    mov bx, 0
    mov cx, 80

.loop:

    mov dl, [cols + bx]
    call .print

    inc byte [cols + bx]

    cmp byte [cols+bx], 25
    jl .check

    mov byte [cols + bx], 0 

    mov ah, 01       ; check if key pressed
    int 0x16

    jne .stop_matrix

.check:
    inc bx
    loop .loop

    call delay
    jmp .main_loop


.print:
    ; for pixels di must be y*320 + x where x,y is (x,y) resolution is 320px by 200px
    ; ascii is similar but with y*80 + x

    ;al = character ah = color
    push ax
    push bx
    push cx
    push dx
    push di

    mov dx, [cols + bx]

    mov dl, [cols + bx]   ; DL = Y (low byte)
    xor dh, dh            ; DH = 0 → DX = Y as 16-bit
    mov ax, dx            ; AX = Y
    mov dx, 80
    mul dx                 ; AX = Y*80
    add ax, bx             ; + X
    shl ax, 1              ; *2 bytes per cell
    mov di, ax

    mov al, [seed]
    add al, 33
    mov [seed], al

    and al, 0x7F
    cmp al, 33
    ja .check_character
    add al, 33

.check_character:
    mov ah, 0x0A

    mov [es:di], al ;char
    mov [es:di+1], ah ;color

    pop di
    pop dx
    pop cx
    pop bx
    pop ax

    ret

.stop_matrix:
    ret

info_cmd:

    pusha 

    mov si, info_text
    call puts

    mov eax, 0
    cpuid

    ; cpu info in ebx, edx, ecx
    mov [cpu_info], ebx
    mov [cpu_info+4], edx
    mov [cpu_info+8], ecx 

    mov byte [cpu_info+12],0

    mov si, cpu_info
    call puts

    mov dword [cpu_info], 0
    mov dword [cpu_info+4], 0
    mov dword [cpu_info+8], 0
    mov byte [cpu_info+12], 0

    popa
    
    mov si, ram_text
    call puts

    pusha
    int 12h
    mov bx,10
    xor cx,cx
    call .ram

.return:
    mov si, kb
    call puts

    mov si, mode_text
    call puts

    mov si, disk_text
    call puts

    mov si, kernel_version
    call puts

    mov byte [cmd_index], 0
    jmp create_new_line

.ram:
    xor dx,dx
    div bx ;ax/bx ax=quotient dx=remainder ax = quotient
    push dx ;save dx
    inc cx

    test ax, ax ;check if ax = 0
    jnz .ram

.print_ram:
    pop dx
    add dl, '0' ;convert to ascii

    mov al, dl
    mov ah, 0x0e
    int 0x10

    loop .print_ram ;loop till cx is empty

    popa
    jmp .return

new_line:
    mov ah, 0x0E

    mov al, 0x0D    
    int 0x10

    mov al, 0x0A
    int 0x10
    jmp puts.loop

create_new_line:

    mov ah, 0x0E
    mov al, 0x0D ; al is equal to > 
    int 0x10 ;print to bios

    mov al, 0x0A
    int 0x10 ;move down one line

    mov si, prompt
    call puts

    mov edi, cmd   ; destination address
    mov ecx, 32       ; number of bytes
    xor eax, eax      ; AL = 0
    rep stosb         ; fill ECX bytes at EDI with AL

    jmp keyboard_input

floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot 

wait_key_and_reboot:
    mov ah, 0
    int 16h                     ; wait for keypress
    jmp 0FFFFh:0                ; jmp back to bios / reboot

.halt: ; halt so the cpu doesn't continously run
    cli
    hlt

; disk routines

;
; Converts an LBA address to a CHS address 
; -ax -> LBA address
;
; Returns
;   -cx [bits 0-5]: sector number
;   -cx [bits 5-16]: cylinder 
;   -dh: head
; 

; Logic Block Addressing to Cylinder Head Sector
lba_to_chs:

    push ax
    push dx

    xor dx, dx                          ; 0 out dx
    div word [bdb_sectors_per_track]    ; ax = LBA / sectors_per_track
                                        ; dx = LBA % sectors_per_track

    inc dx
    mov cx, dx

    xor dx, dx                          ; dx = 0
    div word [bdb_heads]                ; ax = (LBA / sectors_per_track)/ Heads = head
                                        ; dx = (LBA / sectors_per_track) % Heads = cylinder

    mov dh, dl                          ; dh = head
    mov ch, al                          ; ch = cylinder
    shl ah, 6                           ; shift 6 bits

    or cl, ah                           ; higher 2 bits of cy

    pop ax
    mov dl, al
    pop ax
    ret

;
; Reads sector from a disk
; Paramaters:
; -dl: drive number
; - es:bx: memory adress where to store read data 

disk_read: 

    push ax
    push bx
    push cx
    push dx
    push di

    push cx                             ; number of sectors to read
    call lba_to_chs                     ; compute chs
    pop ax                              ; numbers of sectors to read

    mov ah, 02h
    mov di, 3                           ; retry count because floppy disks are unreliable

.retry:
    pusha                               ;save all registers 
    stc                                 ;set carry flag, some bios'es don't set it
    int 13h                             ; carry flag cleared = success
    jnc .done

    popa                                ; pop all regs
    call disk_reset                     

    dec di
    test di, di
    jnz .retry

.fail:
    ; disk load failed
    jmp floppy_error

.done:
    popa

    pop di
    pop dx
    pop cx
    pop bx
    pop ax

    ret

; resets disk controller 
; paramaters: dl (drive number)

disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret

msg_hello: db 'Welcome to HummOS! Type "help" for a list of commands.', ENDL, 0
msg_read_failed: db 'Read from disk failed', ENDL, 0
prompt: db '[user@hummOS]$ ', 0
last_key db 0

cmd: times 32 db 0 ; reserve 32 bytes of memory
cmd_index: db 0 ;cmd index 

cmd_help: db 'help', 0
msg_help: db 0x0A, ' ===============================================', 0x0A,\
                    '                HUMMOS COMMANDS                ', 0x0A,\
                    ' ===============================================', 0x0A,0x0A,\
                    ' COMMAND               DESCRIPTION              ', 0x0A,\
                    ' help                  list of commands         ', 0x0A,\
                    ' clear                 clear terminal           ', 0x0A,\
                    ' quit                  quit system              ', 0x0A,\
                    ' reboot                reboot system            ', 0x0A,\
                    ' time                  display time             ', 0x0A,\
                    ' info                  system info              ', 0x0A,\
                    ' error                 blue screen of death     ', 0x0A,\
                    ' bits                  bits-hex conversion table',0x0A,\
                    ' matrix                matrix rain              ', 0x0A,\
                    ' pong                  pong game                ', 0x0A,\
                    ' snake                 snake game               ', 0x0A,\
                    ' snake-hard            snake hard mode          ', 0x0A,\
                    ' dvd                   bouncing dvd screensaver ', 0x0A,\
                    ' sps                   print sps logo           ', 0x0A,\
                    ' lion                  view lion image          ', 0x0A,\
                    ' unicorn               view unicorn image       ', 0x0A,\
                    ' 2026                  class of 2026            ', 0x0A,\
                    ' credits               sources and credits      ', 0x0A,0

cmd_clear: db 'clear', 0

msg_error: db 'Error: Oops! Command not found!', 0

cmd_quit: db 'quit', 0

cmd_reboot: db 'reboot', 0

cmd_sps: db 'sps', 0

cmd_credits: db 'credits', 0
msg_credits:
    db 0x0A, " ===============================================", 0x0A,\
       "                HUMMOS CREDITS                 ", 0x0A,\
       " ===============================================", 0x0A,\
       " Thank you to my project mentor Mrs. Davidson   ", 0x0A,\
       "                                                ", 0x0A,\
       " Mxy's assembly tutorial on youtube (https://", 0x0A,\
       " www.youtube.com/@MxyAhoy)                      ", 0x0A,\
       "                                                ", 0x0A,\
       " Nanobyte's operating system tutorials on       ", 0x0A,\
       " youtube (https://www.youtube.com/@nanobyte-dev ", 0x0A,\
       " /videos)                                       ", 0x0A,\
       "                                                ", 0x0A,\
       " ASCII Art Generators:                          ", 0x0A,\
       " https://www.asciiart.eu/image-to-ascii         ", 0x0A,\
       " https://patorjk.com/software/taag/             ", 0x0A,\
       " Lion ASCII - https://asciiart.cc/view/12679    ", 0x0A,\
       " Unicorn ASCII - cjr - https://www.ascii-art.de/", 0x0A,\
       " ascii/uvw/unicorn.txt                          ", 0x0A,\
       "                                                ", 0x0A,\
       " GNU GRUB - Free Software Foundation            ", 0x0A,0
                
cmd_pong: db 'pong', 0
ball_x dw 50
ball_y dw 50
ball_vel_x dw 5
ball_vel_y dw 5

left_paddle_y dw 0
left_paddle_x dw 0
right_paddle_y dw 0
right_paddle_x dw 315

pong_color db 0

cmd_snake: db 'snake', 0
cmd_snake_impossible: db 'snake-hard', 0

snake_y: times 100 db 0
snake_x: times 100 db 0

snake_len: db 4
snake_high_score: db 0

;0=right
;1=left
;2=up
;3=down
snake_direction: db 0
food_x: db 100
food_y: db 100

cmd_time: db 'time', 0
time_is: db 0x0A, 'THE CURRENT TIME IS (24h): ', 0

cmd_mr: db 'matrix', 0
cols db 80 dup(0) ; array of 80 bytes, 1 for each y position in matrix
seed db 42

cmd_info: db 'info', 0
cpu_info times 13 db 0
info_text: db 0x0A, 0x0A, '===============================================', 0x0A,\
                    '                HUMMOS SYSTEM INFO              ', 0x0A,\
                    '===============================================', 0x0A,0x0A,\
                    'CPU VENDOR: ', 0x0A, 0

kernel_version: db 0x0A, 'KERNEL: ', 0x0A, 'Version 1.0.4', 0x0A,0
ram_text: db 0x0A, 0x0A, 'RAM:', 0x0A, 0
kb: db ' KB', 0x0A, 0
disk_text: db 0x0A, 'Disk:', 0x0A, 'FLOPPY DISK 2880 sectors * 512 bytes (1.44MB)', 0x0A, 0
mode_text: db 0x0A, 'Mode:', 0x0A, 'VGA BIOS 03h (80x25 text mode)', 0x0A, 0

cmd_error: db 'error', 0
error_color: db 0x1F
error_screen: db 0x1F, "                                                                                ",0x0A,\
             "                                                                                ",0x0A,\
             "                                                                                ",0x0A,\
             "                                                                                ",0x0A,\
             "                                                                                ",0x0A,\
             "                                                                                ",0x0A,\
             "                                   ", 0x71, " HummOS ", 0x1F, "                                     ",0x0A,\
             "                                                                                ",0x0A,\
             "                                                                                ",0x0A,\
             "           An error has occurred. To Continue:                                  ",0x0A,\
             "                                                                                ",0x0A,\
             "           Press Enter to return to HummOS, or                                  ",0x0A,\
             "                                                                                ",0x0A,\
             "           Press CTRL+ALT to restart your computer. If you do this you          ",0x0A,\
             "           will lose any unsaved information in all open applications.          ",0x0A,\
             "                                                                                ",0x0A,\
             "           Error: 0E : 016F : BFF9B3D4                                          ",0x0A,\
             "                                                                                ",0x0A,\
             "                            Press any key to continue                           ",0x0A,\
             "                                                                                ",0x0A,\
             "                                                                                ",0x0A,\
             "                                                                                ",0x0A,\
             "                                                                                ",0x0A,\
             "                                                                                ",0x0A,\
             "                                                                                ",0

cmd_bits: db 'bits', 0
bits_conversion: db 0x0A,' ===============================================', 0x0A,\
                      '         BITS/BYTES/HEX CONVERSION TABLE        ', 0x0A,\
                      ' ===============================================', 0x0A,\
                      ' BITS                HEX          NOTES          ',0x0A,\
                      ' 0000                0            8 bits is equal',0x0A,\
                      ' 0001                1            to 1 byte. So, ',0x0A,\
                      ' 0010                2            a 64 bit regis-',0x0A,\
                      ' 0011                3            ter is actually',0x0A,\
                      ' 0100                4            an 8 byte regi-',0x0A,\
                      ' 0101                5            ster.          ',0x0A,\
                      ' 0110                6                           ',0x0A,\
                      ' 0111                7            1 hex value = 4',0x0A,\
                      ' 1000                8            bits so 2 hex  ',0x0A,\
                      ' 1001                9            values = 8 bits',0x0A,\
                      ' 1010                A            or 1 byte.     ',0x0A,\
                      ' 1011                B                           ',0x0A,\
                      ' 1100                C            Therefore a 64 ',0x0A,\
                      ' 1101                D            bit register   ',0x0A,\
                      ' 1110                E            contains 16 hex',0x0A,\
                      ' 1111                F            values.        ',0x0A,0

cmd_dvd: db 'dvd', 0
x dw 0
y dw 0
x_velocity dw 1
y_velocity dw 1

hummus_logo: db 0x0A, "  $$\   $$\ $$\   $$\ $$\      $$\ $$\      $$\  $$$$$$\   $$$$$$\  ", 0x0A, \
                "  $$ |  $$ |$$ |  $$ |$$$\    $$$ |$$$\    $$$ |$$  __$$\ $$  __$$\ ", 0x0A, \
                "  $$ |  $$ |$$ |  $$ |$$$$\  $$$$ |$$$$\  $$$$ |$$ /  $$ |$$ /  \__|", 0x0A, \
                "  $$$$$$$$ |$$ |  $$ |$$\$$\$$ $$ |$$\$$\$$ $$ |$$ |  $$ |\$$$$$$\  ", 0x0A, \
                "  $$  __$$ |$$ |  $$ |$$ \$$$  $$ |$$ \$$$  $$ |$$ |  $$ | \____$$\ ", 0x0A, \
                "  $$ |  $$ |$$ |  $$ |$$ |\$  /$$ |$$ |\$  /$$ |$$ |  $$ |$$\   $$ |", 0x0A, \
                "  $$ |  $$ |\$$$$$$  |$$ | \_/ $$ |$$ | \_/ $$ | $$$$$$  |\$$$$$$  |", 0x0A, \
                "  \__|  \__| \______/ \__|     \__|\__|     \__| \______/  \______/ ", 0x0A, 0x0A, 0

cmd_chud: db 'chud', 0
chud_logo db "                     @@@@@@@@@@@@@@@@@@@@@@@                                ", 0x0A, \
            "                    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@                  ", 0x0A, \
            "               @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@            ", 0x0A, \
            "             @@@@@@@@@@@@*-....             ..:--=++*##%@@@@@@@@@@@            ", 0x0A, \
            "             @@@@@@-.                   .      .        ...  ...@@@            ", 0x0A, \
            "            @@@@@.                                             .@@@@           ", 0x0A, \
            "            @@@=.                                ..            -@@@@           ", 0x0A, \
            "            @@@.                  #.             .#            =@@@@           ", 0x0A, \
            "           @@@@:                  .#.           .%.            +@@@@           ", 0x0A, \
            "           @@@@:            . .     =..        .@.         .   -%@@@%+%@@      ", 0x0A, \
            "           @@@@.    -+:...              .     .:.            ... %@.   .@      ", 0x0A, \
            "           @@@%.    .@@@@@@@%-....    ..    ..     ....:*@@@@@@*.+.   .@       ", 0x0A, \
            "      @@@@ @@@.      :@@@@@@@@@@@@=...%.    .*...+@@@@@@@@@@@@..%..  .@        ", 0x0A, \
            "      # ..=@@.=%=. .%. ...:-+%@@@@@@#.        .@@@@@@@@@%=... .#.   .@         ", 0x0A, \
            "       @.  ..    ..=.  .-.#@@#*#.-**###%%%##@*@....=*#%@@#=-=:-.  .-@          ", 0x0A, \
            "         #..-.     -.   .:+#####+=. .-.    .-.%.   .#+.#+. .*.   .@            ", 0x0A, \
            "          @-%      .=..          *   *   .  .+%.      .......%.   +            ", 0x0A, \
            "            @@.     .  .-#@@%#*+*%.  %      .%%+. .......  .#@    %            ", 0x0A, \
            "              #.                    .%       =.... ..... ...      @            ", 0x0A, \
            "              #.               .     +       .=                  .@            ", 0x0A, \
            "              #.                     %       .#.                 :             ", 0x0A, \
            "              #.                     %        #.     .          .%             ", 0x0A, \
            "              #.                    -         +.                 @             ", 0x0A, \
            "              #.          . .      .@.        %.                -              ", 0x0A, \
            "               +.                .-:.#%#...:@+.=.           .   +              ", 0x0A, \
            "               @=               .%..  . ..    ..#      .        #              ", 0x0A, \
            "                @.         .          . .          :-.         .@              ", 0x0A, \
            "                @.         .+.      .. ..     ..    .*.       .#               ", 0x0A, \
            "                @:        .%.    ...@...+@-#@=.:@..   .%.     .@               ", 0x0A, \
            "                 %        .  ..%-...      .      ..*-. ..     @                ", 0x0A, \
            "                 @          .*..:-=+**#####*+=--:-=+*@-.     -                 ", 0x0A, \
            "                  %.      .==%.                  .  .#.%.  .:@                 ", 0x0A, \
            "                   @.. ..+-. .+.                 ..*-. ..*.+                   ", 0x0A, \
            "                    @*. ..    .#..          ...+%..      .@                    ", 0x0A, \
            "                      @.   .   ...+@#=--+%%=....  .    .*@                     ", 0x0A, \
            "                       @..  .        ..-=:.           .@                       ", 0x0A, \
            "                         @=.       .%:.   .:#..  . ..@                         ", 0x0A, \
            "                           @+.         .         ..%                           ", 0x0A, \
            "                             @-.              .:@@                              ", 0x0A, \
            "                               @%..         .@                                 ", 0x0A, \
            "                                  @@%****%@@                                    ", 0

sps_logo: db 0x0A, "                 -    -     ", 0x0A,\
            "             ??????  ??????        ", 0x0A,\
            "          ?]  ????????????   ?     ", 0x0A,\
            "         ]??]  -?????????  ????-   ", 0x0A,\
            "        ??????  _??????   ???????  ", 0x0A,\
            "         ??????_  ????  ???????    ", 0x0A,\
            "         -???????  ?-  ??????_l    ", 0x0A,\
            "      ????????????   -???????????? ", 0x0A,\
            "      -???????_         ~????????? ", 0x0A,\
            "       ?-      -???  ????      ??  ", 0x0A,\
            "         ~?????????  ????????-     ", 0x0A,\
            "        ???????????  ???????????   ", 0x0A,\
            "         ??????????  ?????????-    ", 0x0A,\
            "              ?????  ?????         ", 0x0A,\
            "              ?????  ?????         ", 0x0A, 0

art_x: dw 0
art_y: dw 0
logo_index: dw 0
cmd_unicorn: db 'unicorn', 0
unicorn_logo: db "                                                                                ",0x0A,\
             "                             \                                                  ",0x0A,\
             "                              \                               Press Any Key To  ",0x0A,\
             "                               \\\\                           Exit              ",0x0A,\
             "                                \\\\                                            ",0x0A,\
             "                                 >\\/7                                          ",0x0A,\
             "                             _.-(6'  \\                                         ",0x0A,\
             "                            (=___._/` \\                                        ",0x0A,\
             "                                 )  \\ |                                        ",0x0A,\
             "                                /   / |                                         ",0x0A,\
             "                               /    > /                                         ",0x0A,\
             "                              j    < _\\                                        ",0x0A,\
             "                          _.-' :      ``.                                       ",0x0A,\
             "                          \\ r=._\\        `.                                   ",0x0A,\
             "                         <`\\\\_  \\         .`-.                               ",0x0A,\
             "                          \\ r-7  `-. ._  ' .  `\\                              ",0x0A,\
             "                           \\\`,      `-.`7  7)   )                             ",0x0A,\
             "                            \\/         \\|  \\'  / `-._                        ",0x0A,\
             "                                       ||    .'                                 ",0x0A,\
             "                                        \\\\  (                                 ",0x0A,\
             "                                         >\\  >                                 ",0x0A,\
             "                                     ,.-' >.'                                   ",0x0A,\
             "                                    <.'_.'')                                    ",0x0A,\
             "                                      <'                                        ",0x0A,\
             "                                                                                ",0

cmd_lion: db 'lion', 0
lion_logo:
            db\
            "                                                                                ",0x0A,\
            "                                                              Press Any Key To  ",0x0A,\
            "                                                              Exit              ",0x0A,\
            "                                                                                ",0x0A,\
            "                                                                                ",0x0A,\
            "                                                                                ",0x0A,\
            "                      \\|\\||                                                   ",0x0A,\
            "                     -' ||||/                                                   ",0x0A,\
            "                    /7   |||||/                                                 ",0x0A,\
            "                   /    |||||||/`-.____________                                 ",0x0A,\
            "                   \\-' |||||||||               `-._                            ",0x0A,\
            "                    -|||||||||||               |` -`.                           ",0x0A,\
            "                      ||||||               \\   |   `\\\\                       ",0x0A,\
            "                       |||||\\  \\______...---\\_  \\    \\\\                   ",0x0A,\
            "                          |  \\  \\           | \\  |    ``-.__--.              ",0x0A,\
            "                          |  |\\  \\         / / | |       ``---'               ",0x0A,\
            "                        _/  /_/  /      __/ / _| |                              ",0x0A,\
            "                       (,__/(,__/      (,__/ (,__/                              ",0x0A,\
            "                                                                                ",0x0A,\
            "                                                                                ",0x0A,\
            "                                                                                ",0x0A,\
            "                                                                                ",0x0A,\
            "                                                                                ",0x0A,\
            "                                                                                ",0x0A,\
            "                                                                                ",0

cmd_2026: db '2026',0
class_of_2026 db \
"   ___ _                            ",0x0A,\
"  / __\ | __ _ ___ ___              ",0x0A,\
" / /  | |/ _` / __/ __|             ",0x0A,\
"/ /___| | (_| \__ \__ \             ",0x0A,\
"\____/|_|\__,_|___/___/             ",0x0A,\
"                                    ",0x0A,\
"        __   ____   ___ ____   __   ",0x0A,\
"  ___  / _| |___ \ / _ \___ \ / /_  ",0x0A,\
" / _ \| |_    __) | | | |__) | '_ \ ",0x0A,\
"| (_) |  _|  / __/| |_| / __/| (_) |",0x0A,\
" \___/|_|   |_____|\___/_____|\___/ ",0x0A,0
                                    


cmd_hoi4: db 'hoi4',0
hoi4_troops db "   |\                |\                |\                |\",0x0A,\
"   || .---.          || .---.          || .---.          || .---.",0x0A,\
"   ||/_____\         ||/_____\         ||/_____\         ||/_____\",0x0A,\
"   ||( '.' )         ||( '.' )         ||( '.' )         ||( '.' )",0x0A,\
"   || \_-_/_         || \_-_/_         || \_-_/_         || \_-_/_",0x0A,\
"   :-\'`'V'//-.       :-\'`'V'//-.       :-\'`'V'//-.       :-\'`'V'//-.",0x0A,\
"  / ,   |// , `\    / ,   |// , `\    / ,   |// , `\    / ,   |// , `\\",0x0A,\
" / /|Ll //Ll|| |   / /|Ll //Ll|| |   / /|Ll //Ll|| |   / /|Ll //Ll|| |",0x0A,\
"/_/||__//   || |  /_/||__//   || |  /_/||__//   || |  /_/||__//   || |",0x0A,\
"\ \/---|[]==|| |  \ \/---|[]==|| |  \ \/---|[]==|| |  \ \/---|[]==|| |",0x0A,\
" \/\__/ |   \| |   \/\__/ |   \| |   \/\__/ |   \| |   \/\__/ |   \| |",0x0A,\
" /\|_   | Ll_\ |   /|/_   | Ll_\ |   /|/_   | Ll_\ |   /|/_   | Ll_\ |",0x0A,\
" `--|`^\'\'\'^`||_|   `--|`^\'\'\'^`||_|   `--|`^\'\'\'^`||_|   `--|`^",0x0A,\
"    |   |   ||/       |   |   ||/       |   |   ||/       |   |   ||/",0x0A,\
"    |   |   |         |   |   |         |   |   |         |   |   |",0x0A,\
"    |   |   |         |   |   |         |   |   |         |   |   |",0x0A,\
"    |   |   |         |   |   |         |   |   |         |   |   |",0x0A,\
"    L___l___J         L___l___J         L___l___J         L___l___J",0x0A,\
"     |_ | _|           |_ | _|           |_ | _|           |_ | _|",0x0A,\
"ggs (___|___)         (___|___)         (___|___)         (___|___)",0x0A,\
"     ^^^ ^^^           ^^^ ^^^           ^^^ ^^^           ^^^ ^^^",0