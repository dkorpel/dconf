module dconf24.ex0_tempbuf;

import dconf24.allocator;
import std.stdio;

@safe:

struct IntStrings
{
	// Start and end indices
	int s = 0;
	int e = 0;

	// Allocator can be stored in a struct
	Allocator alloc;

	char[] front() return scope
	{
		char[] result = alloc.array!char(10);

		// Simple integer to ascii conversion, nothing exciting 
		size_t p = result.length;
		for (int i = s; i > 0; i/=10) result[--p] = cast(char) ('0' + (i % 10));
		
		return result[p .. $];
	}

	void popFront() scope  
	{
		s++;
	}

	bool empty() scope => s >= e;
}


void main()
{
	Arena a;
	foreach (char[] e; IntStrings(98, 105, a.alloc))
	{
		writeln(e);

		version(TryEscape)
		{
			char[] global;
			global = e;
		}
	}
}
