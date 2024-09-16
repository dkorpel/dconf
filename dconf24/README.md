## Code examples

These are code examples accompanying the presentation.

### [allocator.d](https://github.com/dkorpel/dconf/blob/master/dconf24/allocator.d)

This is the file that you need to import to start using the `Arena` allocator and the `Allocator` interface.
This implementation is meant as a simple, portable base, but some features you might want to add are:

- A fine-tuned groing strategy for allocating new pages in the arena, or:
- Expanding Arena's with memory mapping (OS-specific) instead of keeping a linked list
- Support alignments above 16 (`malloc`'s minimum alignment)
- Only do `GC.addRange` when the array type actually has pointers.
- Make small-size optimizations built into `Arena` by adding a static array field
- Support `pure` / `nothrow` attributes

### [Example 0: Temporary buffer](https://github.com/dkorpel/dconf/blob/master/dconf24/allocator.d)

This shows the most basic usage: use an arena to allocate a dynamic array that's only used in the current function.

```D
Arena a;
Allocator a = a.alloc;
```

### [Example 1: Returning stack memory](https://github.com/dkorpel/dconf/blob/master/dconf24/ex1_return.d)

This example shows how allocated memory can be returned by passing the allocator as a parameter.

```D
char[] concat(scope char[] l, scope char[] r, return scope Allocator alloc = gc)
```

### [Example 2: Storing an allocator in a range](https://github.com/dkorpel/dconf/blob/master/dconf24/ex2_range.d)

This example shows how an allocator can be stored as a struct field, allowing an `InputRange.front()` to return allocated memory.

```D
struct Range
{
    Allocator alloc;
}
```

### [Example 3: Converting to C string](https://github.com/dkorpel/dconf/blob/master/dconf24/ex3_stringz.d)

Using an arena for a toStringz function, similar to `std.internal.string: tempCString`.

### [Example 4: Appending](https://github.com/dkorpel/dconf/blob/master/dconf24/ex4_appending.d)

Appending strings with the concatenation operator usually creates redundant allocations for small fragments created in the process of building a string, even when only the final string is needed:

```
string x = y.toString() ~ z.toString();
// Redundant strings for temporary result of
// y.toString and z.toString, even though we 
// ultimately only care about x. 
```

When all toString functions and concatenation functions use the same Arena however,
an optimization can be made such that the result is essentially built in place,
without redundant allocations.
