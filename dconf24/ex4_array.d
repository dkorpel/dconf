module dconf24.ex4_array;

import dconf24.allocator;
import std.stdio;

@safe:

struct Array(T)
{
    T[] payload;
    Allocator alloc;
    size_t capacity;

    this(Allocator alloc)
    {
        this.alloc = alloc;
    }

    auto opOpAssign(string op : "~")(T value) @trusted
    {
        if (payload.length == capacity)
        {
            scope newPayload = alloc.array!T(1 + capacity * 2);
            newPayload[0 .. payload.length] = payload[];
            this.payload = newPayload;
            this.capacity = capacity * 2;
        }
        this.payload[0] = value;
        return this;
    }

    T[] opIndex() => payload;
}

void main()
{
    Arena a;
    auto arr = Array!int(a.alloc);

    arr ~= 3;

    int[] x = arr[];

    arr ~= 3;
    arr ~= 4;
    arr ~= 5;

    writefln("%s", arr[]);
}
