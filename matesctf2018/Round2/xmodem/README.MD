# XModem
```
Ma dê in Việt Nam
nc 42.117.243.201 9999 -vv
https://drive.google.com/open?id=1VJyTCkswWyhHvEnJFhHOs9Sj7FcfHxbZ
```

# Phân tích chương trình
``` bash
$ file xmodem
xmodem: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux-armhf.so.3, for GNU/Linux 3.2.0, BuildID[sha1]=65eac2d8cc3090ad868af0d90a51b1a56d08fe93, stripped

$ checksec xmodem
    Arch:     arm-32-little
    RELRO:    Full RELRO
    Stack:    Canary found
    NX:       NX enabled
    PIE:      No PIE (0x10000)
```
Run chương trình.
``` bash
$ LD_LIBRARY_PATH=/usr/arm-linux-gnueabihf/lib qemu-arm ./xmodem
***************************************
*                                     *
* 1 - Login                           *
* 2 - Info                            *
* 3 - Add WhiteList Mac               *
* 4 - Ping                            *
* 5 - Set SSID                        *
* 6 - Set Wireless Password           *
* 7 - Exit                            *
*                                     *
***************************************
Your choice: 
```
Dựa và kết quả trả về từ `checksec`, ta thấy có `canary`, `NX enable`, `FULL RELRO` mà trong quá trình phân tích bằng IDA, không hề thấy chương trình sử dụng heap, từ đây có thể suy đoán đây là 1 bài dạng buffer over flow, leak data (canary, libc addr) sau đó sử dụng ROP. OK, `Just ∫du It!`
# Khai thác
+ Bypass authentication.
Để dùng được đầy đủ các chức năng từ 2 - 6, ta phải là **root**. Đây là đoạn code xác thực password:
``` C
v0 = strlen((const char *)&passwd);
if ( !strncmp((const char *)&passwd, (const char *)(200 * i + 0x220EC), v0) )
    break;
```
Vậy nếu ta nhập password có len = 0 thì hàm `strncmp` luôn trả về 0, :v. Vậy nên chỉ cần chọn cặp `username, password = 'root', '\x00'`, login vào và ta có quyền root.
+ Bypass canary.
Ta sẽ sử dụng hàm `Add WhiteList Mac` để bypass qua canary. Hàm này cho phép ta nhập dữ liệu vào 1 mảng string lưu trữ địa chỉ MAC nằm trong bss. Khi nhập, ta có thể ghi đè vào biến lưu size của mảng -> có thể ghi vào bất cứ đâu . Canary cũng được lưu ngay trong bss, nên ta có thể ghi đè canary bằng fake canary của mình.
Lưu ý là khi ghi đè canary trong bss, ta cũng cần ghi đè canary ghi trong stack, nếu không, sẽ dẫn tới `*** stack smashing detected ***`. Nhưng có 1 vấn đề là  do hàm `Add WhiteList Mac` copy buffer từ stack vào bss, nên khi ghi đè canary trong stack, nếu không khéo, buffer sau khi copy vào bss sẽ ghi đè luôn cả `stdin`, `stdout` :v.
Ta sẽ giải quyết như sau: Do hàm nhận giá trị input bằng hàm `scanf`, copy buffer từ stack -> bss bằng hàm `strcpy`, nên nếu ta nhập buffer có chứa null byte, thì ta vừa có thể ghi đè canary trong stack, vừa sửa được canary trong bss mà không làm hỏng `stdin` và `stdout`.
+ ROP sử dụng buffer over flow.
