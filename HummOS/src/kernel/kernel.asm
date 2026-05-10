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

wait_1s:
    push es

    mov ax, 0x0040
    mov es, ax

    mov bx, [es:0x006C]   ; current tick
    add bx, 18            ; ~1 second

.wait:
    mov ax, [es:0x006C]
    cmp ax, bx
    jb .wait

    pop es
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

    pop ax
    pop cx
    pop dx
    pop bx

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

    call wait_1s

    jmp .main_loop

.change_y:
    neg word [y_velocity]
    call wait_1s
    jmp .main_loop

.change_x:
    neg word [x_velocity]
    call wait_1s
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
msg_help: db 0x0A, '===============================================', 0x0A,\
                    '               HUMMOS COMMANDS                ', 0x0A,\
                    '===============================================', 0x0A,0x0A,\
                    'help: help (list of commands)', 0x0A,\
                    'clear: clear terminal', 0x0A,\
                    'quit: quit system', 0x0A,\
                    'reboot: reboot system', 0x0A,\
                    'time: display time', 0x0A,\
                    'info: system info', 0x0A,\
                    'bits: bits-bytes-hex conversion table',0x0A,\
                    'matrix: matrix rain', 0x0A,\
                    'dvd: bouncing dvd logo', 0x0A,\
                    'sps: print sps logo', 0x0A, 0

cmd_clear: db 'clear', 0

msg_error: db 'Error: Oops! Command not found!', 0

cmd_quit: db 'quit', 0

cmd_reboot: db 'reboot', 0

cmd_sps: db 'sps', 0

cmd_time: db 'time', 0
time_is: db 0x0A, 'THE CURRENT TIME IS (24h): ', 0

cmd_mr: db 'matrix', 0
cols db 80 dup(0) ; array of 80 bytes, 1 for each y position in matrix
seed db 42

cmd_info: db 'info', 0
cpu_info times 13 db 0
info_text: db 0x0A, 0x0A, '===============================================', 0x0A,\
                    '               HUMMOS SYSTEM INFO              ', 0x0A,\
                    '===============================================', 0x0A,0x0A,\
                    'CPU VENDOR: ', 0x0A, 0

kernel_version: db 0x0A, 'KERNEL: ', 0x0A, 'Version 1.0.4', 0x0A,0
ram_text: db 0x0A, 0x0A, 'RAM:', 0x0A, 0
kb: db ' KB', 0x0A, 0
disk_text: db 0x0A, 'Disk:', 0x0A, 'FLOPPY DISK 2880 sectors * 512 bytes (1.44MB)', 0x0A, 0
mode_text: db 0x0A, 'Mode:', 0x0A, 'VGA BIOS 03h (80x25 text mode)', 0x0A, 0

cmd_bits: db 'bits', 0
bits_conversion: db 0x0A,'===============================================', 0x0A,\
                      '        BITS/BYTES/HEX CONVERSION TABLE        ', 0x0A,\
                      '===============================================', 0x0A,\
                      'BITS                HEX          NOTES          ',0x0A,\
                      '0000                0            8 bits is equal',0x0A,\
                      '0001                1            to 1 byte. So, ',0x0A,\
                      '0010                2            a 64 bit regis-',0x0A,\
                      '0011                3            ter is actually',0x0A,\
                      '0100                4            an 8 byte regi-',0x0A,\
                      '0101                5            ster.          ',0x0A,\
                      '0110                6                           ',0x0A,\
                      '0111                7            1 hex value = 4',0x0A,\
                      '1000                8            bits so 2 hex  ',0x0A,\
                      '1001                9            values = 8 bits',0x0A,\
                      '1010                A            or 1 byte.     ',0x0A,\
                      '1011                B                           ',0x0A,\
                      '1100                C            Therefore a 64 ',0x0A,\
                      '1101                D            bit register   ',0x0A,\
                      '1110                E            contains 16 hex',0x0A,\
                      '1111                F            values.        ',0x0A,0

cmd_dvd: db 'dvd', 0
x dw 0
y dw 0
x_velocity dw 1
y_velocity dw 1

hummus_logo: db 0x0A, "$$\   $$\ $$\   $$\ $$\      $$\ $$\      $$\  $$$$$$\   $$$$$$\  ", 0x0A, \
                "$$ |  $$ |$$ |  $$ |$$$\    $$$ |$$$\    $$$ |$$  __$$\ $$  __$$\ ", 0x0A, \
                "$$ |  $$ |$$ |  $$ |$$$$\  $$$$ |$$$$\  $$$$ |$$ /  $$ |$$ /  \__|", 0x0A, \
                "$$$$$$$$ |$$ |  $$ |$$\$$\$$ $$ |$$\$$\$$ $$ |$$ |  $$ |\$$$$$$\  ", 0x0A, \
                "$$  __$$ |$$ |  $$ |$$ \$$$  $$ |$$ \$$$  $$ |$$ |  $$ | \____$$\ ", 0x0A, \
                "$$ |  $$ |$$ |  $$ |$$ |\$  /$$ |$$ |\$  /$$ |$$ |  $$ |$$\   $$ |", 0x0A, \
                "$$ |  $$ |\$$$$$$  |$$ | \_/ $$ |$$ | \_/ $$ | $$$$$$  |\$$$$$$  |", 0x0A, \
                "\__|  \__| \______/ \__|     \__|\__|     \__| \______/  \______/ ", 0x0A, 0x0A, 0


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

sps_logo: db 0x0A, "                 -    -                 ", 0x0A, \
            "             ??????  ??????             ", 0x0A, \
            "          ?]  ????????????   ?          ", 0x0A, \
            "         ]??]  -?????????  ????-        ", 0x0A, \
            "        ??????  _??????   ??????<       ", 0x0A, \
            "         ??????_  ????  ???????         ", 0x0A, \
            "         -???????  ?-  ??????_l         ", 0x0A, \
            "      ????????????   -????????????      ", 0x0A, \
            "      -???????_         ~?????????      ", 0x0A, \
            "       ?-      -???  ????      ??       ", 0x0A, \
            "         ~?????????  ????????-          ", 0x0A, \
            "        ???????????  ???????????        ", 0x0A, \
            "         ??????????  ?????????-         ", 0x0A, \
            "              ?????  ?????              ", 0x0A, \
            "              ?????  ?????              ", 0x0A, 0
