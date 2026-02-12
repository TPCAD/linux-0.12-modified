# Bootloader

简单地说，bootloader 应实现以下功能：

1. 加载内核
2. 保存硬件参数
3. 开启保护模式
4. 跳转到内核执行。

## bootsect.S

如 2.2 节所述，Linux 的 bootloader 分成两部分，第一部分是`bootsect.S`，这部分的主要功能是加载 bootloader 的第二部分`setup.S`和内核到内存，并跳转到`setup.S`执行。

头文件`config.h`定义了一些内存段地址和内核大小的宏。

```c
#ifndef _CONFIG_H
#define _CONFIG_H

/* bootsect.S 的起始段地址 */
#define DEF_INITSEG 0x9000
/* setup.S 的起始段地址 */
#define DEF_SETUPSEG 0x9020
/* system 模块的起始段地址 */
#define DEF_SYSSEG 0x1000
/* system 模块的大小，与段地址相加得到结束段地址
 * 0x8000 表示 0x80000 B，即 512 KB
 * 与 0x1000 相加刚好 0x9000，没覆盖 bootsect.S*/
#define DEF_SYSSIZE 0x8000

#endif
```

BIOS 初始化硬件后，CPU 处于**实模式**。因此汇编代码应以实模式运行。

`bootsect.S`首先将自身移动到内存地址`0x90000`。早期可能 Linus 认为`0x7c00`这个地址较低，可能会被覆盖，所以将`bootsect.S`移动到一个较高的地址。然后从硬盘中读取`setup.S`到内存地址`0x90200`，Oak 将它放在了第 2 到第 5 个扇区。接着再从硬盘读取内核到内存地址`0x10000`。从第 6 个扇区开始，共 1024 个扇区。最后跳转到`0x90200`执行`setup.S`。

因为是 MBR，所以必须在结尾写入`0x55aa`，又因为 x86 CPU 是小端序，所以最终写入`0xaa55`。

加载内核时，因为`int 0x13 ah=0x02`中断一次最多读 0xff 个扇区，而内核有 1024 个扇区。为了方便设计循环，Oak 选择每次读`0x80`个扇区。 0x80 正好被 1024 整除，且 0x80 个扇区，即 0x10000 个字节，刚好使得缓冲区段地址每次都增加 0x1000，方便设计循环。

```asm
load_system:
    movw $0x0, %bx              # 缓冲区偏移地址
    movw $0x0080, %dx           # 磁头号 0，驱动器号 0x80
    movw $0x0006, %cx           # 磁道号 0，扇区号 6

do_read:
    movw %es, %ax               # 每次从 es 获取上次的源地址
    addw $0x1000, %ax           # 每轮大循环复制 0x10000 字节
    movw %ax, %es
retry:                          # 发生错误时的重试入口
    cmpw $0x9000, %ax           # 结束条件
    jz ok_load_system
    movw $0x0200 + 0x80, %ax    # 读扇区服务，扇区数
    int $0x13
    jnc do_read

    /* 使用 0x13 号中断重置硬盘，ah=0 复位功能号，dl=0x80 第一块硬盘 */
    movb $0x80, %dl
    xorb %ah, %ah
    int $0x13
    /* 重新读取 setup.S */
    jmp retry

ok_load_system:
```

## setup.S

`setup.S`首先使用 BIOS 获取内存、显示器和硬盘的参数。这些参数保存在内存地址`0x90000`之后，这里原本是`bootsect.S`的位置，在跳转到`setup.S`后以不再使用。

`setup.S`接着将内核移动到内存地址`0x0`，这使得内核有更多可使用的连续内存。`0x0`原本是 BIOS 保存中断向量表和其他数据的地方，覆盖这里以为着后面将不能再使用 BIOS 中断。

### 保护模式

进入保护模式之前还有一些准备工作：

- 加载 GDT
- 开启 A20 线
- 初始化 8259A

#### 分段式内存管理

分段机制将内存分成多个大小不一，可以重叠的段。每个段由一个**段描述符**描述，段描述符记录了段的起始地址，范围以及各种属性，所有的段描述符都被存储在**全局描述符表**（GDT）中。GDT 的地址和大小会被保存在寄存器`gdtr`中。**段选择器**提供了段描述符在 GDT 中的偏移位置。关于 GDT 的更多内容可以阅读 2.3 节。

分段除了划分内存外，还有控制访问权限的作用。段描述符中的 DPL 字段与 CPU 的特权级对应，只有对应的特权级才能访问内存段。

进入保护模式需要先设置 GDT，除了第一项全为 0 的段描述符，还需要一个代码段和一个数据段。Oak 使用分页机制管理内存，为了消除分段带来的影响，Oak 将段的范围设置为整个物理内存，也就是 16 MiB（这是当时 linus 的内存大小）。

- 段基地址：0x0
- 段界限：`((1024*1024*16) / (1024*4)) - 1`
- 访问类型：
  - 存在位：1
  - DPL：0，内核态
  - 描述符类型位：1，代码段或代码段
  - Type
    - X：1，代码段
    - C：0，只能由对应特权级执行
    - R：1，可读
    - A：0，未被访问
  - G：1，4 KiB 颗粒度
  - DB：1，保护模式
  - L：0，非长模式
  - A：置 0

代码段与数据段只有`X`位不同，其余字段的值都相同。

```asm
.equ memory_base, 0
.equ memory_limit, ((1024*1024*16) / (1024*4)) - 1

# 代码段
gdt_code:
    # 段界限前 16 位
    .word memory_limit & 0xffff
    # 段基地址前 16 位
    .word memory_base & 0xffff
    # 段基地址 16～23 位
    .byte (memory_base >> 16) & 0xff
    # 访问类型
    .byte 0b10011010
    # 标志与段界限后 4 位
    .byte 0b11000000 | ((memory_limit >> 16) & 0xf)
    # 段基地址 24～31 位
    .byte (memory_base >> 24) & 0xff
# 数据段
gdt_data:
    .word memory_limit & 0xffff
    .word memory_base & 0xffff
    .byte (memory_base >> 16) & 0xff
    # 访问类型
    .byte 0b10010010
    .byte 0b11000000 | ((memory_limit >> 16) & 0xf)
    .byte (memory_base >> 24) & 0xff
gdt_end:
```

#### A20 线

保护模式（Protected Mode）是 80286 及其后续处理器的主要工作模式。尽管大多数时候保护模式都与 32 位模式等价，但 80286 仍然是一个 16 位处理器。在 8088 上，当寻址超过 1 MB 时，会发生**环绕**。比如地址`0x100000`实际上访问的是地址`0x00000`，最高位被丢弃了。当时的许多应用都依赖这一特性工作。而在 80286 上，地址线被扩展到了 24 位。虽然 80286 可以在实模式下模拟 8088 的运行以兼容旧应用，但因为地址线的扩展，超出 1 MB 的部分不会再发生环绕，这就使得许多应用无法在 80286 上运行。为了保证兼容性，IBM 引入了 Gate-A20。

IBM 在 A20 线和系统总线之间插入了一个名为 Gate-A20 的逻辑门。Gate-A20 由软件决定通断以控制是否接受来自 A20 的信号。当关闭时，超过 1MB 的地址仍然会发生环绕。

在操作系统开发领域，「A20 线」所指代的一般就是 Gate-A20，而不是地址线。 现在，开启 A20 线是操作系统进入保护模式的重要步骤，而且通常在引导阶段完成。

开启 A20 线最常用的方法是设置键盘控制器的端口。由于键盘控制器的速度很慢，人们引进了一个 A20 快速门选项，使用端口`0x92`控制 A20 线。

```asm
# 开启 A20 线
in $0x92, %al
orb $2, %al
out %al, $0x92
```

开启 A20 线后应该检查是否正确开启。通过比较地址`0x100000`和`0x000000`可以确认是否正确开启。

```asm
    xorl %eax, %eax
1:  incl %eax
    movl %eax, 0x000000
    cmpl %eax, 0x100000
    je 1b
```

#### 8259A

进入保护模式后将不能再使用 BIOS 中断。与 BIOS 中断类似，保护模式下的中断通过一张**中断描述符表**（IDT）管理，其结构与 GDT 类似。同时，硬件产生的外部中断由**可编程中断控制器**（PIC）8259A 管理。在`setup.S`中，Linux 只加载一张长度为 0 的 IDT 和初始化 8259A 以确保能够进入保护模式。更多关于中断的信息将在下一章介绍。

```asm
/* 初始化 8259A */
movb $0x11, %al
outb %al, $0x20
jmp .+2
jmp .+2
outb %al, $0xa0
jmp .+2
jmp .+2

movb $0x20, %al
outb %al, $0x21
jmp .+2
jmp .+2
movb $0x28, %al
outb %al, $0xa1
jmp .+2
jmp .+2

movb $0x04, %al
outb %al, $0x21
jmp .+2
jmp .+2
movb $0x02, %al
outb %al, $0xa1
jmp .+2
jmp .+2

movb $0x01, %al
outb %al, $0x21
jmp .+2
jmp .+2
outb %al, $0xa1
jmp .+2
jmp .+2

movb $0xff, %al
outb %al, $0x21
jmp .+2
jmp .+2
outb %al, $0xa1
```

#### 进入保护模式

寄存器`cr0`的最低位控制 CPU 工作在实模式还是保护模式。置 1 为保护模式，置 0 为实模式。在修改寄存器前应关闭中断，防止发生错误。完成设置后，应该立即进行一次远跳转，避免继续执行未完成的 16 位指令。

```asm
cli

movl %cr0, %eax
orb $1, %al
movl %eax, %cr0

ljmp $code_selector, $protected_mode

.code32
protected_mode:
```

## 参考资料

1. [A20 line](https://en.wikipedia.org/wiki/A20_line)
2. [Protected Mode](https://wiki.osdev.org/Protected_Mode)
3. [Protected mode](https://en.wikipedia.org/wiki/Protected_mode)
