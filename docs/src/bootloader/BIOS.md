# BIOS

**TL;DR**

BIOS 会在开机后初始化硬件并提供访问硬件的中断函数。基于 BIOS 的 Bootloader 需要使用这些中断函数来加载操作系统内核。

---

BIOS（Basic Input/Output System），基础输入输出系统，是早期计算机上一种初始化硬件，为操作系统提供运行时服务的固件。BIOS 一开始存储在主板的 ROM 芯片中，无法修改，后来则存储在闪存中，允许厂商升级更新 BIOS。现在 BIOS 已经逐渐被 UEFI 取代。

BIOS 是计算机通电后执行的第一个程序，它会初始化并测试硬件（即加电自检），然后从大容量存储设备（软盘、硬盘等）加载 bootloader。此时 CPU 处于 16 位模式也就**实模式**。

## BIOS 内存布局

BIOS 会初始化前 1 MiB 的内存，具体布局如下表所示：

| 起始地址  | 结束地址  | 大小     | 用途               |
| --------- | --------- | -------- | ------------------ |
| `0x000`   | `0x3FF`   | 1KB      | 中断向量表         |
| `0x400`   | `0x4FF`   | 256B     | BIOS 数据区        |
| `0x500`   | `0x7BFF`  | 29.75 KB | 可用区域           |
| `0x7C00`  | `0x7DFF`  | 512B     | MBR 加载区域       |
| `0x7E00`  | `0x9FBFF` | 607.6KB  | 可用区域           |
| `0x9FC00` | `0x9FFFF` | 1KB      | 扩展 BIOS 数据区   |
| `0xA0000` | `0xAFFFF` | 64KB     | 用于彩色显示适配器 |
| `0xB0000` | `0xB7FFF` | 32KB     | 用于黑白显示适配器 |
| `0xB8000` | `0xBFFFF` | 32KB     | 用于文本显示适配器 |
| `0xC0000` | `0xC7FFF` | 32KB     | 显示适配器 BIOS    |
| `0xC8000` | `0xEFFFF` | 160KB    | 映射内存           |
| `0xF0000` | `0xFFFEF` | 64KB-16B | 系统 BIOS          |
| `0xFFFF0` | `0xFFFFF` | 16B      | 系统 BIOS 入口地址 |

## BIOS 中断调用

中断是 BIOS 提供的硬件操作接口。内存前 1 KiB 是 BIOS 中断向量表，共有 256 项，每项 4 字节。表中每一项其实是一个地址，指向对应的中断处理程序或参数表。

BIOS 中断通过汇编指令 `int` 调用。如调用 `0x13` 号中断：`int $0x13`。大多数中断需要通过寄存器提供参数。

下面是一个调用中断的示例，其功能是向屏幕写一个字符。

```asm
movb $0x0e, %ah    # 功能号
movb $0x53, %al    # 字符 ASCII 码
movb $0x01, %bh    # 页号
int $0x10          # 中断调用
```

### 0x10

`0x10` 中断是 BIOS 提供的显示服务，可以设置显示模式，获取和设置光标位置，滚动窗口等等。

设置显示模式：

```asm
    # 调用 BIOS 0x10 号中断，设置显示模式
    # 操作码 ah = 00h，参数 al = 03h
    movw $0x3, %ax
    int $0x10
```

打印字符：

```asm
    # 调用 BIOS 0x10 号中断，设置显示模式
    # 操作码 ah = 0eh，参数 al = 字符
    movb $0x41, %al
    movw $0xe, %ax
    int $0x10
```

### 0x13

`0x13` 中断是 BIOS 提供的低级磁盘服务，可以读写硬盘等。

读取硬盘：

```asm
    movw $DAPACK, %si # Disk Address Packet
    movb $0x42, %ah   # 操作码
    movb $0x80, %dl   # 硬盘号，0x80 是第一个硬盘
    int $0x13

DAPACK:
    .byte 0x10   # DAP Size，通常置为 16
    .byte 0      # 不使用，置 0
    .word 0x4    # 读取的扇区数量
    # 内存地址，segment:offset，x86 是小端序，如果分开定义 segment 和 offset，
    # 应该先定义 offset
    .word 0x1000 # offset
    .word 0      # segment
    # 读取的起始扇区，使用 LBA 地址，注意小端序
    .long 0x2
    .long 0
```

## Reference

1. [INT 10H](https://zh.wikipedia.org/wiki/INT_10H)
2. [Video Modes](https://mendelson.org/wpdos/videomodes.txt)

