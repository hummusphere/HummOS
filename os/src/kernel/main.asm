org 0x7C00 ; code starts at 0x7C00, where the BIOS loads the boot sector
bits 16 ; 16 bit code so that the os runs simpler

%define ENDL 0x0D, 0x0A 

; go straight to main
start:
    jmp main

puts: 
    ; save registers in stack
    push si
    push ax

.loop:
    lodsb ; load next character in al
    or al, al ; verify if next character is null
    jz .done ;conitional jump

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

    hlt

.halt: ; halt so the cpu doesn't continously run
    jmp .halt

msg_hello: db 'Hello, World!', ENDL, 0

times 510 - ($ - $$) db 0 ; fill the rest of the boot sector with zeros
dw 0AA55h ; boot signature, must be 0xAA55 for the BIOS to recognize it as a valid boot sector