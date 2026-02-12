# stdarg

`stdarg.h`是定义了一系列关于**可变参数**的宏。在 32 位 CPU 上，C 函数调用会将所有参数按从右到左的顺序入栈，也就是说第一个参数保存在栈顶。

## va_list

```c
typedef char *va_list;
```

`va_list`是`char*`的别名。

## __va_rounded_size

```c
#define __va_rounded_size(TYPE)                                                \
    (((sizeof(TYPE) + sizeof(int) - 1) / sizeof(int)) * sizeof(int))
```

栈操作的最小长度与 CPU 的位宽相同，因此入栈时若参数大小不是 4 字节对齐（32 位 CPU），就会被强制对齐到 4 的倍数。比如 6 字节的参数会占用 8 字节的栈空间。宏`__va_rounded`的作用便是`TYPE`对齐后的字节数，`TYPE`可以是类型或表达式。

## va_start

```c
#define va_start(AP, LASTARG)                                                  \
    (AP = ((char *)&(LASTARG) + __va_rounded_size(LASTARG)))
```

要找到可变参数表的位置，只需要找到可变参数的前一个参数的地址，然后加上它占用的栈空间即可得到可变参数表的地址。`LASTARG`是可变参数的前一个参数。

## va_end

```c
void va_end(va_list); // 在 gnulib 中定义
#define va_end(AP)
```

在 Linux 0.12 中宏`va_end`不做任何事情，但为了兼容性，仍声明`va_end`函数。

## va_arg

```c
#define va_arg(AP, TYPE)                                                       \
    (AP += __va_rounded_size(TYPE), *((TYPE *)(AP - __va_rounded_size(TYPE))))
```

宏`va_arg`展开后是一个逗号表达式。第一个表达式将指针指向下一个可变参数，第二个表达式获取前一个可变参数的值作为整个逗号表达式的返回值。
