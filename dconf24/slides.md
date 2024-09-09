---
marp: true
theme: uncover
title: Translating C to D
_class: lead
paginate: true
backgroundColor: #f8fff4
header: 'https://github.com/dkorpel/dconf'
math: mathjax

style: |
  .columns {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 1rem;
  }

-----------------------------------------------------------
### Avoid the Garbage Collector in 80 lines
Dennis Korpel
<!--_header: ''-->

-----------------------------------------------------------
# Garbage Collection
Memory is automatically managed by occasionally pausing all threads and scanning for memory still in use, and freeing the rest.*

<!--_footer: ∗we'll get back to this-->

-----------------------------------------------------------
# Phobos API
```D
import std.stdio, std.process;

void printPath()
{
    string s = environment.get("PATH");
    writeln(s);
}
```
-----------------------------------------------------------
# Windows API
```D
import std.stdio, core.sys.windows.windows;

void printPath()
{
    const lengthZ = GetEnvironmentVariableW("PATH", null, 0);
    wchar[] buf = new wchar[lengthZ];
    const len = GetEnvironmentVariableW("PATH", buf.ptr, buf.length);
    writeln(buf[0 .. len]);
}
```
-----------------------------------------------------------
# Conclusion
Thank you Garbage Collector, for the ergonomics you provide

-----------------------------------------------------------
<!--_backgroundColor: white-->
<!--_header: ''-->
# <!--fit--> The end
-----------------------------------------------------------

# Except...

* Scenarios where you can’t use GC
* I tried `@nogc` approaches so you don’t have to!
* Often awkward, until epiphany:
* `@safe @nogc` allocator in just 80 lines
* Built on top of `malloc` and `free`

-----------------------------------------------------------
# r/TQDC

![Image](img/tqdc.png)

-----------------------------------------------------------

```D
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
```

<!--_footer: https://github.com/dkorpel/dconf/blob/master/dconf24/allocator.d-->

-----------------------------------------------------------
**Spoiler:**
```D
string environmentGet(string key, return scope Allocator alloc = gc)
{
    char[] buf = alloc.array!char(1024);
    // Call OS function
    return buf[0 .. n];
}

void printPath()
{
    Arena a;
    string s = environmentGet("PATH", a.alloc);
    writeln(s);
    // a.~this();
}
```

-----------------------------------------------------------
# Whoami
- Msc. Computer Science from TU Delft
- Part time Issue Manager for D Language Foundation
- Part time D programmer at SARC
- 2023: DConf talk about safe stack memory

-----------------------------------------------------------
# Coming up
- Why not use GC?
- Failed `@nogc` approaches
- The 80 line solution
- Evaluation
- ~~DIP1000~~ scoped pointer updates

-----------------------------------------------------------

<!--_backgroundImage: url('https://raw.githubusercontent.com/dkorpel/ctod/master/docs/background.svg')-->
# Why not use GC?

-----------------------------------------------------------

# GC Phobia

![Image height:250](img/newsgroup-gc-phobia.png)

-----------------------------------------------------------

# Controversy

- Always about those darn pauses
- I find myself on neither side
- Reference Counting better for real-time?

-----------------------------------------------------------
## (Automatic) Reference counting

```D
struct RefCountedString {
    string* payload;
    int* count;

    this(string s) {
        payload = malloc(s.length);
        count = new int(1);
    }

    this(this) { ++*count; }

    ~this() {
        if (--*count == 0)
            free();
    }
}
```
-----------------------------------------------------------
# Audio programming

48 Khz sample rate, 10 ms latency

```D
float phase = 0;

void audioCallback(float[] buffer)
{
    foreach (i; 0 .. buffer.length)
    {
        buffer[i] = sin(phase);
        phase += 0.0576;
    }
}
```
<!--Callback needs to compute 480 samples with a strict deadline-->
-----------------------------------------------------------
# Garbage collector comes

![Image](img/dennis-garbage-truck.png)

Takes several ms to collect

-----------------------------------------------------------

# Deadline missed?
- No, GC only pauses threads it knows
- Audio thread is already 'detached'
- What if we need to allocate inside audioCallback?
- Reference Counting wouldn't have helped

-----------------------------------------------------------
### Audio guidelines

![bg right height:320](img/adc-principles.png)
<!--_footer: The Golden Rules of Audio Programming - Pete Goodliffe - ADC16-->

- No syscalls
- No locks
- No malloc
- No file I/O

-----------------------------------------------------------

### @nogc should have a reason

![Image height:500](img/nogc-project.png) ⚠️
<!--_footer: https://github.com/dlang/project-ideas/issues/56-->

-----------------------------------------------------------

### @nogc should have a reason

![Image height:400](img/dplug-dub.png) ✅
<!--_footer: https://code.dlang.org/packages/dplug-->

-----------------------------------------------------------
<!--_backgroundImage: url('https://raw.githubusercontent.com/dkorpel/ctod/master/docs/background.svg')-->
# Simplicity

-----------------------------------------------------------
### 1960s: Linear Congruential Random

$X_{n+1} = \left( a X_n + c \right)\bmod m$

<!--_footer: https://en.wikipedia.org/wiki/RANDU-->
```D
int seed = 1;
int RANDU()
{
    seed = seed * 65539 + 0;
    return seed;
}
```
-----------------------------------------------------------

### 1997: MERSENNE TWISTER

<!--_header: ''-->
![bg](img/twister.png)

-----------------------------------------------------------

### 1997: MERSENNE TWISTER

- 624 ints storage
- Default PRNG Excel, Matlab, GNU octave, Phobos
- Fails TestU01 statistical tests (2007)

-----------------------------------------------------------
### 2014: PCG Random
- More complex than the twister?
- LCG64 actually pretty good

```C
uint32_t pcg32_random_r(pcg32_random_t* rng)
{
    uint64_t oldstate = rng->state;
    rng->state = oldstate * 6364136223846793005ULL + (rng->inc|1);
    uint32_t xorshifted = ((oldstate >> 18u) ^ oldstate) >> 27u;
    uint32_t rot = oldstate >> 59u;
    return (xorshifted >> rot) | (xorshifted << ((-rot) & 31));
}
```
-----------------------------------------------------------
### 2014: PCG Random

```
1011101000000010100100100010100010010011010000100010111111011001
10111
  |  01000000010100100100010100010010
  |                 |
  |                 |
 23
```

-----------------------------------------------------------
### Quite Okay Formats

- Dominic Szablewski
- Similar to PNG / MP3
- Encoder / decoder are 400 lines

<!--_footer: https://qoiformat.org/-->

-----------------------------------------------------------
### Walter's quote

> Anybody can come up with a a complex solution. A simple one takes genius. You know it's genius when others say: "phui, anyone could have done that!" Except that nobody did.

<!--_footer: https://forum.dlang.org/post/t2i7mg$22am$1@digitalmars.com-->

-----------------------------------------------------------

<!--_header: ''-->
<video controls="controls" src="img/RC.mp4"></video>

-----------------------------------------------------------
### Reference Counting complexity
- `__mutable` / `__metadata` storage class (DIP1xxx)
- Borrows (DIP1021)
- Copying, Moving, and Forwarding (DIP1040)

<!--_footer: https://github.com/RazvanN7/DIPs/blob/Mutable_Dip/DIPs/DIP1xxx-rn.md-->
-----------------------------------------------------------
### GC complexity

- 7000 lines in druntime
- Platform specific
- Centralized, needs to know everything

- False pointers on 32-bit
- Missing GC.addRoot
- Virus scanners

-----------------------------------------------------------
<!--_backgroundImage: url('https://raw.githubusercontent.com/dkorpel/ctod/master/docs/background.svg')-->
## 6 suboptimal `@nogc` solutions

-----------------------------------------------------------
### 0. Manually free

```D
void main()
{
    string s = environmentGet("PATH");
    scope(exit)
        free(s.ptr);
    writeln(s);
}
```

- Not memory safe (double free)
- Clutters code (esp. unittests and scripts)

-----------------------------------------------------------
### 0. Manually free
- `malloc` ⟺ `free`
- `ITypeinfo.GetFuncDesc` ⟺ `ReleaseFuncDesc`
- `ITypeinfo.GetVarDesc` ⟺ `ReleaseVarDesc`
- `ITypeinfo.GetNames` ⟺ ~~`ReleaseNames`~~ `SysFreeString`
- `IMoniker.GetDisplayName` ⟺ ~~`SysFreeString`~~ `CoTaskMemFree`
-----------------------------------------------------------

![bg right height:250](img/right0.png)

The borrow checker catches this right?
```D
void main() @live
{
    int* x = cast(int*) malloc(4);
    free(x); ✅
}
```
<!--_footer: https://dlang.org/blog/2019/07/15/ownership-and-borrowing-in-d/-->

-----------------------------------------------------------

![bg right height:250](img/right1.png)

Right?
...
```D
void main() @live
{
    int* x = new int;
    free(x); // No error by design
}
```
<!--_footer: https://dlang.org/blog/2019/07/15/ownership-and-borrowing-in-d/-->

-----------------------------------------------------------
### 1. Don’t allocate

- Return lazy ranges
- Works for simple algorithms (splitter, chain)
- Voldemort types instead of simple arrays
- `std.path: buildPath`
- Annoying to write for complex algorithms

-----------------------------------------------------------
<!--_header: ''-->

![Image height:700](img/array-vs-range.png)


-----------------------------------------------------------
### 2. Stack memory

- Automatically cleaned up
- Can’t return it
```D
char[] environmentGet(string x)
{
    char[1024] buf = void;
    // GetEnvironmentVariable(buf[], )
    return buf[]; // Error
}
```
-----------------------------------------------------------
### 2. Stack memory
- Annoying to call
- Small, fixed sizes only

```D
void main()
{
    char[1024] buf;
    const n = environmentGet(buf[]);
    const str = buf[0 .. n];
}
```

-----------------------------------------------------------
### 3. OutputRanges / Appenders

```D
void environmentGet(O)(string key, ref O sink)
{
    import std.range: put;
    put(sink, "...");
}

void main()
{
    Appender!string appender;
    environmentGet("PATH", appender);
    string result = a.data();
}
```

-----------------------------------------------------------
### 3. OutputRanges / Appenders

- Annoying to write / call
- Still need a `@nogc` Appender
- Hard to make `@safe`

-----------------------------------------------------------
### 4. Null garbage collection

> ~~Memory is automatically managed by occasionally pausing all threads and scanning for memory still in use, and freeing the rest.*~~

-----------------------------------------------------------
### 4. Null garbage collection

- "Pretend there's infinite memory"
- Null garbage collector: never deallocate
- Works if enough RAM

-----------------------------------------------------------

<!--_footer: https://devblogs.microsoft.com/oldnewthing/20180228-00/?p=98125-->

```
From: k...@rational.com (Kent Mitchell)
Subject: Re: Does memory leak?
Date: 1995/03/31

Norman H. Cohen (nco...@watson.ibm.com) wrote:
: The only programs I know of with deliberate memory leaks are those whose
: executions are short enough, and whose target machines have enough
: virtual memory space, that running out of memory is not a concern.
: (This class of programs includes many student programming exercises and
: some simple applets and utilities; it includes few if any embedded or
: safety-critical programs.)

This sparked an interesting memory for me.  I was once working with a
customer who was producing on-board software for a missile.  In my analysis
of the code, I pointed out that they had a number of problems with storage
leaks.  Imagine my surprise when the customers chief software engineer said
"Of course it leaks".  He went on to point out that they had calculated the
amount of memory the application would leak in the total possible flight time
for the missile and then doubled that number.  They added this much
additional memory to the hardware to "support" the leaks.  Since the missile
will explode when it hits its target or at the end of its flight, the
ultimate in garbage collection is performed without programmer intervention.
```

-----------------------------------------------------------

### 4. Null garbage collection
![Image height:500](img/walter-null-gc.png)

-----------------------------------------------------------

### 4. Null garbage collection

- I use this in WebAssembly
- "Out Of Memory" risk

-----------------------------------------------------------
### 5. Scope Array

```D
void f()
{
    size_t length = 1024;
    auto a = ScopeArray!char(length);

    scope char[] buf = a.getSlice();

    char[] path = environmentGet("PATH", buf);

    writeln(path);

    // sa.~this();
}
```

-----------------------------------------------------------
### 5. Scope Array

```D
void f()
{
    size_t length = 500;
    auto a = Arena();

    scope Allocator alloc = a.allocator();

    environmentGet(buf, alloc);

    // sa.~this();
}
```

-----------------------------------------------------------
# The 80 line solution
-----------------------------------------------------------
```D
struct Allocator
{
    AllocatorBase* x;
}

struct AllocatorBase
{
    immutable AllocateFunction allocate;
}

alias AllocateFunction = ubyte[] function(size_t size, size_t alignment, scope void* context);
```

Did you just re-invent classes and delegates?
(Yes, for C compatibility)

-----------------------------------------------------------
# Arenas

- Our own stack
- But accessed through a variable
- Bump the pointer to allocate
- Throw everything out in destructor

-----------------------------------------------------------
# Hannah Montana functions

```D
string environmentGet(string key, Allocator alloc = gc)
{
    char[] buf = alloc.array!char(1024);
    // Call OS function
    return buf[0 .. n];
}
```

-----------------------------------------------------------
# Hannah Montana functions

```D
void main()
{
    string s = environmentGet("PATH");

    Arena a;
    string s = environmentGet("PATH", a.alloc);
}
```

- Best of both worlds!

-----------------------------------------------------------


### The good and bad

| 😎                       | ☹️                           |
|--------------------------|------------------------------|
| Freeing at end of scope  | Manually calling free        |
| Freeing big chunks       | Pairing each malloc ⟺ free  |
| GC API (by default)      | Cluttered call-sites         |

---

# BUT WHAT ABOUT

-----------------------------------------------------------

# `@nogc`

- Unlike `return scope` for lifetimes, there’s no `@inout_nogc`
- Cheat: pretend it is `@nogc`
- Hot take: `@nogc` should not be part of function type
- Linting tool instead

-----------------------------------------------------------
# Ranges

- Works! See `dconf24/ex2_range.d`

```D
struct Range
{
    Allocator allocator;
}
```

-----------------------------------------------------------
# Dynamic arrays

- See `dconf24/ex3_array.d`

```D
struct Array(T)
{
    T[] slice;
    size_t capacity;
    Allocator alloc;
}
```

-----------------------------------------------------------
# Overhead

- GC also has 2-3x overhead...
- Use memory mapping instead of linked list
- 35 bits of real RAM (16 GB)
- 48 bits virtual address space 256 TB
- Stack already does this (2000 threads * 8 MB)

-----------------------------------------------------------
# Unpredictable lifetimes

- What if allocation depends on user input?
- Pre-allocate a pool
- Roll your own free-list, bitmapped block, GC...

<!--_footer: https://bitbashing.io/gc-for-systems-programmers.html-->
<!--https://forum.dlang.org/post/tnajfjmvvyqardwhxegi@forum.dlang.org-->
-----------------------------------------------------------
# Ugly signatures

-----------------------------------------------------------
## Context struct

![Image height:500](img/jblow-context.png)

<!--_footer: https://youtu.be/uZgbKrDEzAs?si=clQT4OAd4j66KJ8i&t=2303-->
-----------------------------------------------------------

### In Odin
```
main :: proc()
{
    context.user_index = 456
    {
        context.allocator = my_custom_allocator()
        context.user_index = 123
        supertramp() // `context` is implicitly passed
    }
    assert(context.user_index == 456)
}
```

<!--_footer: https://odin-lang.org/docs/overview/#implicit-context-system-->

-----------------------------------------------------------

<!--_footer: https://github.com/odin-lang/Odin/blob/a25a9e6ebe58510cfac20e1187f41a01ec3ec2b2/base/runtime/core.odin#L434-L446-->

```D
struct Context
{
    Allocator allocator;
    Allocator temp_allocator;
    Assertion_Failure_Proc assertion_failure_proc;
    Logger logger;
    Random_Generator random_generator;

    void* user_ptr;
    ptrdiff_t user_index;

    // Internal use only
    void* _internal;
}
```

-----------------------------------------------------------

## Aftermath

- Deleted tons of destructors, `free` calls, `// #BAD_TRUSTED` comments
- Deleted `ScopeArray` and `Appender` (just need `Array`)
- It only gets better

-----------------------------------------------------------

## GPU memory



-----------------------------------------------------------


# DIP1000 issues

-----------------------------------------------------------

# Duplicated code

- Refactored `dmd/escape.d`
- Number of `if` statements 310 => 240
- Fixing bugs in the process

-----------------------------------------------------------

# Invalidation

- Just don't invalidate 🙈

-----------------------------------------------------------

# Struct fields / transitive scope

```D
struct Context
{
    string source;
    HashMap!(string, Declaration) symbolTable;

}
```

-----------------------------------------------------------

- GC avoidance should be intentional
- Don’t call `free()` yourself
- Arenas are like named stack memory
- `return scope` + default parameters marry GC and manual memory
- `@nogc` should be a linting tool, not part of function type

-----------------------------------------------------------
