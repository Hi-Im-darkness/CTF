BITS 32

xchg eax, ecx
mov al, 0x3
xor ebx, ebx
mov dl, 0x64
int 0x80
