module dconf24.ex3_stringz;

import dconf24.allocator;

public char* toStringz(scope const(char)[] str, return scope Allocator alloc)
{
	auto result = alloc.array!char(str.length + 1);
	result[0 .. str.length] = str[];
	result[str.length] = '\0';
	return &result[0];
}

void main()
{
	Arena a;
	const(char)* c = "abc".toStringz(a.alloc);
	assert(c[0 .. 4] == "abc\0");
}
