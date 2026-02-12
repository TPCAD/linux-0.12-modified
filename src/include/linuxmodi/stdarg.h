#ifndef _STDARG_H
#define _STDARG_H

typedef char *va_list;

// 计算 TYPE 对齐到 4 字节后的大小。TYPE 可以是类型或表达式。
#define __va_rounded_size(TYPE)                                                \
    (((sizeof(TYPE) + sizeof(int) - 1) / sizeof(int)) * sizeof(int))

// 使 AP 指向可变参数表。LASTARG 是可变参数表的前一个参数。
#define va_start(AP, LASTARG)                                                  \
    (AP = ((char *)&(LASTARG) + __va_rounded_size(LASTARG)))

// 在当前平台，宏 va_end 不做任何事情。
// 若是其他平台，可以会从 gnulib 中找到该函数
void va_end(va_list); // 在 gnulib 中定义
#define va_end(AP)

// 获取当前可变参数，并使指针指向下一个可变参数
#define va_arg(AP, TYPE)                                                       \
    (AP += __va_rounded_size(TYPE), *((TYPE *)(AP - __va_rounded_size(TYPE))))

#endif
