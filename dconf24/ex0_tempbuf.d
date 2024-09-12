module dconf24.ex0_tempbuf;

import dconf24.allocator;

void main() @safe
{
    Arena a;
    Allocator alloc = a.alloc;

    int[] arr = alloc.array!int(100);
    arr[0] = 3;
}
