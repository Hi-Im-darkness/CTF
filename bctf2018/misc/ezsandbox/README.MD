## Analyze
- File **server.py**: give key match md5 hash code to up ELF file. Run file ELF with custom lib (**scf.so**).
- File **scf.so**: Custom lib which filter some syscall. Hook into `_libc_start_main` func.

## Bypass
- Brute force key.
- Write a `execve('/bin/sh', ...)` shellcode and compile it with elf format. Then patch binary: jump from EP to `main`. (file **ezsandbox**).
