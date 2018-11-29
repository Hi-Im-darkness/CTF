## Analyze
- Binary
-- Three function: create notes, delete note, edit note.
-- Create notes: `malloc` notes with fix size : 0x50 and we only `malloc` 3 notes.
-- Edit notes: edit content of notes
-- Delete notes: `free` notes and we can choice `Clear (y/n)` entry of note in `notes` array.
- Libc
-- 2.27 -> using tcache.

## Idea
- With 3 notes, we can using **tcache dup** to malloc to header of exist chunk. Edit size of this chunk = **0x91** (so when this chunk free, it fall into unsorted bin), free until tcache bin full.
- When tcache bin of size **0x90** full, edit size = **0x51** (origin size) and free it -> fall into tcache bin size **0x50**. edit size = **0x91** and free -> fall into unsorted bin.
- Overwrite 2 byte in `fd` pointer of this chunk -> `stdout` addr (brute force 4bit). malloc 2 chunk, then the 2nd chunk will be malloc in `stdout` addr.
- Using FILE attack to leak libc addr. Then using **tcache dup** to edit `__free_hook` addr.
