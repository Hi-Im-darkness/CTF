## Analyze
- Simlar `three` binary except add `show` function and we can only malloc 2 notes.

## Problem
- With `show` function, we can leak data but with only 2 notes, we cannot using **tcache dup** technique.

## Idea
- Free notes until tcache bin full. (size tcachebin = 7)
- Free one more time, this chunk fall into fast bin.
- Malloc 1st time, return chunk come from tcache bin and tcache bin next entry is NULL. Set content of this chunk = header addr of this chunk. (size tcachebin = 6)
- Malloc 2nd time, return chunk also come from fastbin because tcache next entry is NULL. tcache bin not full and fast bin have 1 chunk (header addr of origin chunk) -> copy 1 chunk to tcache bins -> tcache bin full. (size tcachebin = 7)
- Free origin chunk, it fall into fastbin. Next malloc, return chunk come from tcache (header addr of origin chunk).
- Edit size of origin chunk -> craft chunk with size fall into unsorted bin -> leak libc addr -> use same techique to malloc into `__free_hook` addr.
