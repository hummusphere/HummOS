; boot.asm
[org 0x7C00]
bits 16

start:
    jmp load_kernel

load_kernel:
    mov ax, 0x0000
    mov es, ax
    mov bx, 0x7E00        ; Load address of kernel

    mov ah, 0x02          ; BIOS function: read sectors
    mov al, 50             ; Number of sectors to read
    mov ch, 0             ; Cylinder
    mov cl, 2             ; Sector 2
    mov dh, 0             ; Head
    mov dl, 0x00          ; Drive 0 (floppy or HDD)
    int 0x13              ; BIOS interrupt

    jmp 0x0000:0x7E00     ; Jump to loaded kernel

times 510-($-$$) db 0
dw 0xAA55                 ; Boot signature