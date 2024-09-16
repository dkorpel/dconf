module dconf24.ex4_appending;

import dconf24.allocator;
import std.stdio;

@safe:

struct Combiner(T)
{
    T[] array;
    Allocator alloc;

    this(Allocator alloc)
    {
        this.alloc = alloc;
    }

    auto opBinary(string op : "~")(const T[] rhs) @trusted
    {
        // The two arrays are adjacent
        if (this.array.ptr + this.array.length == rhs.ptr)
        {
            this.array = this.array.ptr[0 .. this.array.length + rhs.length];
        }
        else
        {
            scope newStuff = alloc.array!T(this.array.length + rhs.length);
            newStuff[0 .. this.length] = this.array[];
            newStuff[this.length .. $] = rhs[];
            this.array = newStuff;
        }
        return this;
    }

    auto opBinary(string op : "~", S)(S rhs)
    {
        return this ~ rhs.toString(alloc);
    }

    alias array this;
}

alias cat = Combiner!char;

struct Person
{
    string name;
    string surname;

    const(char)[] toString(return scope Allocator alloc) const
    {
        return alloc.cat ~ name ~ " " ~ surname;
    }
}

void main()
{
    Person person = Person("John", "Doe");
    Arena a;
    char[] s = a.alloc.cat ~ "Hello " ~ person ~ "!";

    writeln(s);
}
