import core.memory, core.bitop;

Allocator gc() => Allocator(null);

struct Allocator
{
	AllocatorBase* x;

	T[] array(T)(size_t length) return scope @trusted if (__traits(isPOD, T))
	{
		if (x == null || __ctfe)
			return new T[length];
		return cast(T[]) x.allocate(T.sizeof * length, T.alignof, x);
	}
}

alias AllocateFunction = ubyte[] function(size_t size, size_t alignment, scope void* context);

struct AllocatorBase
{
	immutable AllocateFunction allocate;
}

struct Arena
{
	@system private AllocatorBase base = AllocatorBase(&arenaAllocate);
	@system private ArenaPage* page = null;
	@system private ubyte[] buffer; // slice of free space

	private static ubyte[] arenaAllocate(size_t size, size_t alignment, scope void* ctx) @system =>
		(cast(Arena*) ctx).allocate(size, alignment);

	@disable this(this);
	@disable void opAssign();

	this(return scope ubyte[] initialBuffer) scope @trusted
	{
		this.buffer = initialBuffer;
	}

	ubyte[] allocate(size_t size, size_t alignment) scope @trusted
	{
		const shift = (-cast(size_t) buffer.ptr) & (alignment - 1);
		if (size + shift >= this.buffer.length)
			newPage(size);
		else
			this.buffer = this.buffer[shift .. $];
		auto result = this.buffer[0 .. size];
		this.buffer = this.buffer[size .. $];
		return result;
	}

	private void newPage(size_t size) @trusted
	{
		const newSize = size_t(1) << (1 + bsr(ArenaPage.sizeof + size)); // round up to power of 2
		assert(newSize >= size);
		auto p = pureMalloc(newSize);
        GC.addRange(p, newSize, null);
		assert(p);
		auto oldPage = this.page;
		this.page = cast(ArenaPage*) p;
		this.page.prev = oldPage;
		this.buffer = (cast(ubyte*) p)[ArenaPage.sizeof .. newSize];
	}

	Allocator alloc() scope return @trusted => __ctfe ? gc() : Allocator(cast(AllocatorBase*) &this);

	~this() scope @trusted
	{
		while (this.page)
		{
			void* toFree = this.page;
			this.page = this.page.prev;
			pureFree(toFree);
		}
	}
}

private struct ArenaPage
{
    ArenaPage* prev;
}
