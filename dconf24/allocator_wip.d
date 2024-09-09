module dconf24.allocator_wip;

import core.memory, core.bitop;

Allocator gc() => Allocator(null);

struct Allocator
{
	AllocatorBase* x;

	T[] array(T)(size_t length)
	{
		if (x == null)
			return new T[length];
		return cast(T[]) x.allocate(T.sizeof * length, T.alignof, x);
	}
}

alias AllocateFunction = ubyte[] function(size_t size, size_t alignment, scope void* context);

struct AllocatorBase
{
	immutable AllocateFunction allocate;
}

ubyte[] arenaAllocate(size_t size, size_t alignment, scope void* ctx)
{
	return (cast(Arena*) ctx).buffer[0 .. size];
}

struct Arena
{
	AllocatorBase base = AllocatorBase(&arenaAllocate);
	ubyte[] buffer;

	Allocator alloc()
	{
		return Allocator(cast(AllocatorBase*) &this);
	}

	~this()
	{
		free(buffer.ptr);
	}
}
