module dconf24.ex1_return;

import dconf24.allocator;
import std.stdio;

@safe:

char[] global;

void main()
{
    Arena a;
    char[4] l = "Hey ";
    char[4] r = "Jude";

    auto result = concat(l[], r[], a.alloc);
    writeln(result);

    version(none)
        global = result; // Error: scope variable `result` assigned to global variable `global`
    // We can't escape local Arena memory to a global variable

    auto resultGc = concat(l[], r[]);
    writeln(resultGc);

    global = resultGc;
}

char[] concat(scope char[] l, scope char[] r, return scope Allocator alloc = gc)
{
    char[] result = alloc.array!char(l.length + r.length);
    result[0 .. l.length] = l[];
    result[l.length .. $] = r[];
    return result;
}
