# LD

## 命令行选项

### -e entry --entry=entry

指定程序的入口地址为符号`entry`。

### -m emulation

模拟对应`emulation`的链接器。可用`ld -V`查看可用的 emulation。

### --oformat output-format

指定输出文件的类型。可用`objdump -i`查看可用类型。与`objcopy -O`可能不同。

### -r --relocatable

部分链接，生成可被用作 ld 输入的可重定位文件（Relocatable File）。与`-s`等删除符号的选项使用时会保留符号表（.symtab）。

### -static

静态链接。

### -s --strip-all

忽略所有符号信息（symbol），会导致 GDB 找不到调试符号。

### -S --strip-debug

忽略所有调试器符号信息（debugger symbol）。

### -T scriptfile

使用链接脚本。脚本会替换 ld 的默认链接脚本，因此脚本必须完整表述链接过程。

### -Ttext=org

指定`text`段的起始地址。

另有`-Tbss=org`和`-Tdata=org`。

### -x --discard-all

删除所有局部符号（local symbol）。

## Linker Script

Linker Script 以 `.ld` 或 `.lds` 结尾，用于指示链接器如何进行链接。

### 入口地址

在链接脚本中可以使用 `ENTRY(symbol)` 指定入口地址。

```ld
ENTRY(_start)
```

### SECTIONS

SECTIONS 命令告诉链接器如何组织输入的各个段 以及如何在内存中排列输出的段。

```ld
SECTIONS {
    sections-command
    sections-command
    ...
}
```

### Location counter

`.` 是一个特殊的链接器变量，它表示当前位置离起始位置的字节偏移量。通常情况下，起始位置，也就是 `SECTIONS` 的地址是 0，因此，此时的 `.` 是绝对地址。当 `.` 出现在段描述中时，它表示当前位置离当前所在的段的字节偏移量。

```ld
SECTIONS {
    . = 0x10000; /* 绝对地址 */
    .text {      /* 将 .text 置于 0x10000 */
        *(.text)
        /* 相对地址，起始地址当前段的地址，即 0x10000，*/
        /* 实际地址则是 0x10040 */
        . = 0x40;
        *(.test)
    }
}
```

### 内建函数

#### FILL

填充间隙。

```ld
. = 0x10000;
FILL(0x00); /* 用 0x00 填充 0x40 字节
. = 0x10040;
```

## 参考文献

[LD document](https://sourceware.org/binutils/docs-2.39/ld.html)
