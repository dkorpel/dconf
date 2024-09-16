/*
Demonstrate basic usage: use an arena to allocate a dynamic array that's only used in the current function.
*/
module dconf24.ex0_tempbuf;

import dconf24.allocator;

void main() @safe
{
    Arena a;
    Allocator alloc = a.alloc;

    int[] arr = alloc.array!int(100);
    arr[0] = 3;
}
