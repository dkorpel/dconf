# [DConf 2024](https://dconf.org/2024/#dennisk)


### Avoid the Garbage Collector in 80 Lines

- Slides (html): [dkorpel.github.io/dconf](https://dkorpel.github.io/dconf)
- Slides (pdf): [TODO]()

---

# [DConf 2023](https://dconf.org/2023/#dennisk)

### Stack memory is awesome

- [Video (YouTube)](https://youtu.be/b0hRAdjCFtI)
- [Slides](https://dconf.org/2023/slides/korpel.pdf)

**Corrections:**
- At 4:30, the guard page is shown to be "64 KiB". The typical page size I meant to list here is "4 KiB"

### Lightning talk: Building DMD

- [Video (YouTube)](https://youtu.be/Ks5vXpDO4H0?si=CeiZExLRhTI0K-b7&t=2187)
- [Forum post: Building the compiler in 2 seconds with `dmd -i`](https://forum.dlang.org/post/ltpjhrigitsizepwcuhs@forum.dlang.org)
- [Pull Requests refactoring the backend](https://github.com/dlang/dmd/pulls?q=is%3Apr+author%3Adkorpel+label%3ABackend+label%3ARefactoring+is%3Aclosed+prototypes)

# [Dconf online 2022](https://dconf.org/2022/online/#dennisk)

### Translating C to D

- [Slides (PDF)](https://dconf.org/2022/online/slides/korpel.pdf)
- [glfw-d](https://github.com/dkorpel/glfw-d)
- [libsoundio-d](https://github.com/dkorpel/libsoundio-d)

# [Dconf 2022](https://dconf.org/2022/#dennisk)

### The Jack of all Trades

- [Video (YouTube)](https://www.youtube.com/watch?v=f9RzegZmnUc)
- [Slides (Google Docs)](https://docs.google.com/presentation/d/1mlIB8_OjchBrf-HDJfhhkjcNKSk2y5DKYus7qr5HoEQ/edit?usp=sharing)
- [Slides (PDF)](https://dconf.org/2022/slides/korpel.pdf)
- [Computer Algebra System WebAssembly demo](https://dkorpel.github.io/dconf2022/)

### Lighting talk: return

- [Video (YouTube)](https://youtu.be/GOKIH7AQJR0?si=Fz7lDpihzjg575Wr&t=741)
- [Slides (Google Docs)](https://docs.google.com/presentation/d/1cAFNsrWqA9--lYtlnRx4Wvt7Vk5a5rhwgh8tVuP0BWY)

The final code:
```D
alias retսrn = noreturn;
auto returո=()return{return(
return retսrn retսrn)return{
return retսrn;};};
```
