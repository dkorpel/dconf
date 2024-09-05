module dconf24.ex0_tempbuf;

import dconf24.allocator;

@safe:

void main()
{
    Arena a;
    int[] arr = a.alloc.array!int(100);

    arr[0] = 3;

    version(TryEscape)
    {

    }
}
