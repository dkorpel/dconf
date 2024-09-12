## Code examples

These are code examples accompanying the presentation.


### allocator.d

This is the file that you need to import to start using the `Arena` allocator and the `Allocator` interface.
This implementation is meant as a simple, portable base, but some features you might want to add are:

- A fine-tuned groing strategy for allocating new pages in the arena, or:
- Expanding Arena's with memory mapping (OS-specific) instead of keeping a linked list
- Support alignments above 16 (`malloc`)
- Only do `GC.addRange` when the array type actually has pointers.
- Add a small-size optimization in `Arena` by default by adding a little stack buffer as a field
- Support `pure` / `nothrow` attributes

### Example 0: Temporary buffer

```D
Arena a;
Allocator a = a.alloc;
```

### Example 1: Returning stack memory

```D
char[] concat(scope char[] l, scope char[] r, return scope Allocator alloc = gc)
```

### Example 2: Storing an allocator in a range

```D
struct Range
{
    Allocator alloc;
}
```

### Example 3: Converting to C string


### Example 4: Dynamic array


### Example 4: Appending


