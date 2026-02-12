#ifndef _STRING_H
#define _STRING_H

extern inline int strlen(const char *s) {
    register int __res __asm__("cx");
    __asm__("cld\n\t"
            "repne\n\t"
            "scasb\n\t"
            "notl %0\n\t"
            "decl %0"
            : "=c"(__res)
            : "D"(s), "a"(0), "0"(0xffffffff));
    return __res;
}

#endif
