; kernel.asm
[org 0x7E00]
bits 16

%define ENDL 0x0D, 0x0A 

mov ax, 0x0033   ; 80x50 text mode
int 0x10

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
ebr_volume_label:           db 'HUMMUS   OS'
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
    mov si, os_logo
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
    mov ah, 0x00 ; BIOS key press
    int 0x16     ;AL = ascii character
    ;al becomes whatever is typed

    cmp al, 0x0D ;enter pressed
    je cmd_parse ; jmp if equal enter

    mov bl, [cmd_index] ; get the value inside cmd index
    mov [cmd + bx], al ;set the position of cmd + bx to al
    inc byte [cmd_index] ;inc cmd index

    mov ah, 0x0E ; print al to bios 
    int 0x10

    jmp keyboard_input

cmd_parse:
    mov bl, [cmd_index]
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

    mov byte [cmd_index], 0 

    mov ah, 0x0E

    mov al, 0x0D    
    int 0x10

    mov al, 0x0A
    int 0x10

    mov si, msg_error
    call puts

    jmp create_new_line

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

clear_cmd:
    mov ax, 0x0003
    int 0x10        ; set text mode 80x25, clears screen
    xor si, si
    mov byte [cmd_index], 0
    jmp main

quit_cmd:
    mov ax, 0x5307
    mov bx, 0x0001
    mov cx, 0x0003
    int 0x15

reboot_cmd:
    jmp 0FFFFh:0

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

msg_hello: db 'Welcome to HummusOS! Type "-h" for a list of commands.', ENDL, 0
msg_read_failed: db 'Read from disk failed', ENDL, 0
prompt: db '[user@hummusOS]$ ', 0

cmd: times 32 db 0 ; reserve 32 bytes of memory
cmd_index: db 0 ;cmd index 

cmd_help: db '-h', 0
msg_help: db 'Commands', 0x0A, '-h: help (list of cmds)', 0x0A, '-c: clear terminal', 0x0A, '-q: quit system', 0x0A, '-r: reboot system', 0x0A, '-sps: print sps logo', 0

cmd_clear: db '-c', 0

msg_error: db 'Error: cmd not found', 0

cmd_quit: db '-q', 0

cmd_reboot: db '-r', 0

cmd_sps: db '-sps', 0

hummus_logo: db 0x0A, "$$\   $$\ $$\   $$\ $$\      $$\ $$\      $$\ $$\   $$\  $$$$$$\  ", 0x0A, \
                 "$$ |  $$ |$$ |  $$ |$$$\    $$$ |$$$\    $$$ |$$ |  $$ |$$  __$$\ ", 0x0A, \
                 "$$ |  $$ |$$ |  $$ |$$$$\  $$$$ |$$$$\  $$$$ |$$ |  $$ |$$ /  \__|", 0x0A, \
                 "$$$$$$$$ |$$ |  $$ |$$\$$\$$ $$ |$$\$$\$$ $$ |$$ |  $$ |\$$$$$$\  ", 0x0A, \
                 "$$  __$$ |$$ |  $$ |$$ \$$$  $$ |$$ \$$$  $$ |$$ |  $$ | \____$$\ ", 0x0A, \
                 "$$ |  $$ |$$ |  $$ |$$ |\$  /$$ |$$ |\$  /$$ |$$ |  $$ |$$\   $$ |", 0x0A, \
                 "$$ |  $$ |\$$$$$$  |$$ | \_/ $$ |$$ | \_/ $$ |\$$$$$$  |\$$$$$$  |", 0x0A, \
                 "\__|  \__| \______/ \__|     \__|\__|     \__| \______/  \______/ ", 0x0A, 0x0A, 0

os_logo db "                   $$$$$$\   $$$$$$\                              ", 0x0A, \
                 "                  $$  __$$\ $$  __$$\                             ", 0x0A, \
                 "                  $$ /  $$ |$$ /  \__|                           ", 0x0A, \
                 "                  $$ |  $$ |\$$$$$$\                              ", 0x0A, \
                 "                  $$ |  $$ | \____$$\                             ", 0x0A, \
                 "                  $$ |  $$ |$$\   $$ |                             ", 0x0A, \
                 "                   $$$$$$  |\$$$$$$  |                             ", 0x0A, \
                 "                   \______/  \______/ ", 0x0A,0x0A, 0

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