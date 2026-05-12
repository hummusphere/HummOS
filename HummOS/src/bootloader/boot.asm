; boot.asm
[org 0x7C00]
bits 16

%define ENDL 0x0D, 0x0A

start:
    mov si, msg_boot
    call puts
    jmp load_kernel

puts: 
    ; save registers in stack
    push si
    push ax

.loop:
    lodsb ; load next character in al
    or al, al ; verify if next character is null
    jz .done ;conitional jump
    
    cmp al, 0x0A
    je .new_line

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

.new_line:
    mov ah, 0x0E

    mov al, 0x0D    
    int 0x10

    mov al, 0x0A
    int 0x10
    jmp .loop

load_kernel:
    mov si, msg_kernel
    call puts
    mov ax, 0x0000
    mov es, ax
    mov bx, 0x7E00        ; Load address of kernel

    mov ah, 0x02          ; BIOS function: read sectors
    mov al, 50            ; Number of sectors to read
    mov ch, 0             ; Cylinder
    mov cl, 2             ; Sector 2
    mov dh, 0             ; Head
    mov dl, 0x00          ; Drive 0 (floppy or HDD)
    int 0x13              ; BIOS interrupt

    jmp 0x0000:0x7E00     ; Jump to loaded kernel


msg_boot: db 'Starting bootloader ...', 0x0A, 0
msg_kernel: db 'Starting kernel ...', 0x0A, 0
times 510-($-$$) db 0
dw 0xAA55                 ; Boot signature