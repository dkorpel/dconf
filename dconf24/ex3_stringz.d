/**
This example shows how an arena can be given a stack buffer
for small size optimization, similar to existing alternatives:

- `toCStringThen` in dmd
- `TempCBuffer` in Phobos


*/
module dconf24.ex3_stringz;

import dconf24.allocator;

/// Returns: `str` with a zero-terminator added so it can be passed to C functions
public char* toStringz(scope const(char)[] str, return scope Allocator alloc = gc)
{
	auto result = alloc.array!char(str.length + 1);
	result[0 .. str.length] = str[];
	result[str.length] = '\0';
	return &result[0];
}

void main()
{
	ubyte[64] buffer = void;
	Arena a = Arena(buffer[]);

	const(char)* c = "abc\n".toStringz(a.alloc);

	import core.stdc.stdio;
	printf(c);
	assert(c[0 .. 5] == "abc\n\0");

	// Assert we're actually using the stack buffer
	assert(c == cast(void*) buffer.ptr);
}
