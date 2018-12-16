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
+ ROP.

    Ở hàm `Login` có 1 lỗi buffer over flow khi nhập password, nhờ đó mình có thể ghi đè 2 bytes của save pc address. Chỉ với 2 bytes ghi đè được thì rất khó để có thể làm gì đó được, nên mình sẽ tìm gadget để chuyển `sp` cho trỏ đến 1 buffer mình control được data trong bss hoặc data segment.
    Gadget đó là `mov sp, r7 ; pop {r7, pc}`, với việc control `r7` = bss/data address ta có thể thay đổi giá trị `sp`. Address mình chọn là address của ssid string nằm trong data segment vì ta có thể control 40 bytes bắt đầu từ địa chỉ chỉ của ssid string bằng 2 hàm `Set SSID` và `Set Wireless Password`.
    
    Giờ tiếp theo mình cần tìm các gadget khác có thể control giá trị các thanh ghi `r0`, `r1`, `r2`. Dưới đây là các gadget mình tìm được:
    ```
    mov r2, sb ; mov r1, r8 ; mov r0, r7 ; blx r3
    pop.w {r3, r4, r5, r6, r7, r8, sb, pc}
    ```
    Nhưng chỉ với 40 bytes buffer, mình vẫn không thể làm được điều gì hay ho, không kể `sp` đang trỏ đến vùng nằm ngay sau vùng readonly data, nên khi gọi hàm, push thanh ghi vào, `sp` bị giảm xuống, khi `sp` giảm đến vùng readonly, chương trình sẽ crash :(. Sau khi thử khá nhiều cách, mình cũng tìm ra 1 cách đi đúng hướng, đó là gọi hàm `read` vì hàm `read` khá đơn giản nên sẽ không cần push quá nhiều thứ vào stack. Và destination mình nhắm tới là mảng MAC address nằm ở bss. Nhưng trước khi read, mình cần chuyển `sp` trỏ vào destination trước, vì mình muốn sau khi read xong, ROP có thể thực thi tiếp tại destination  đó được luôn. 
    
    1 lưu ý nữa là mình read tận 800 bytes luôn và lại dịch `sp` lên 700 bytes vì để tránh việc khi gọi hàm mà `sp` chạm phải readonly segment. Rồi đến đây thì có khá nhiều hướng mở ra. Trong quá trình thi mình nghĩ ra 2 hướng. Cách thứ nhất là gọi hàm `popen` dùng command `nc`  để reverse shell về vps của mình (thực ra cũng không phải của mình lol :v). Cách thứ 2 là gọi `puts` để leak ra libc addr rồi gọi `read` thêm 1 lần nữa để  ret2libc.
    
    Cá nhân mình thấy cách thứ nhất đơn giản hơn vì chỉ cần read 1 lần ROP, nên mình làm theo cách này trước. Local chạy ngon lành cành đào, đem lên chạy với remote thì tạch :(. Lúc đó mình nghĩ chắc cách này không phải cách tác giả mong muốn nên rất có thể trên server không có `nc` cho mình dùng. Nên lại lóc cóc code theo cách thứ 2.
    
    Code xong cách 2, local vẫn chạy ầm ầm, lên remote vẫn tạch . Thật là magic.  Sau 1 hồi debug đi debug lại, vẫn không biết mình sai ở đâu, mình đành tâm linh 1 chút, add thêm 1 vài dword null vào ROP của mình (xem poc để biết thêm chi tiết :v), thì thật magic nó chạy :v và lấy flag thôi. Sau khi thi xong mình nghĩ rất có thể lý do mà code lần đầu của mình tạch rất có thể cũng là vì lý do  này, mình thử lại, và đúng thế thật sau khi add thêm pad, code chạy :v. Mình nghĩ rất có thể do mình debug bằng `qemu` nên có sự sai khác 1 chút với việc chạy trên remote server  với kiến trúc arm xịn.
    
    Dưới đây là poc của mình.
    [exploit.py]: ./exploit.py
    ```
    $ ./exploit.py remote
    [+] Opening connection to 42.117.243.201 on port 9999: Done
    [*] Libc addr: 0x76e07000
    [*] Switching to interactive mode

    $ cat /home/xmodem/flag
    matesctf{xmodem_ma_de^_in_VietNam}
    ```

Cảm ơn mọi người đã đọc hết bài writeup dài và loằng ngoằng này của mình. Lời cuối xin cảm ơn Viettel vì đã tổ chức 1 giải matesctf chất lượng, và đặc biệt cảm ơn anh **Phiêu Lãng** vì đã ra bài pwn arm hay và chất lượng này.
