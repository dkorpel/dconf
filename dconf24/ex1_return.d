module dconf24.ex1_return;

import dconf24.allocator;
import std.stdio;

@safe:

void main()
{
    Arena a;
    char[4] l = "hey ";
    char[4] r = "jude";

    auto result = concat(l[], r[], a.alloc);

    writeln(result);
}

char[] concat(scope char[] l, scope char[] r, return scope Allocator alloc = gc())
{
    char[] result = alloc.array!char(l.length + r.length);
    result[0 .. l.length] = l[];
    result[l.length .. $] = r[];
    return result;
}
