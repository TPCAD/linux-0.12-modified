# GDT

GDT（Global Descriptor Table），全局描述符表，是一个用于描述内存分布的数组，数组的每一项称为段描述符（Segment Descriptor），用于描述一段内存区域。GDT 的第一项必须为全 0。在进入保护模式之前要先将 GDT 的地址和大小加载到寄存器`gdtr`中。

## 段描述符

在 32 位 CPU 上，段描述符的大小为 8 字节，结构如下：

```language
|63                 56|55            52|51          48|47 |46 45| 44|43  40|39                            32|
+-----------------------------------------------------+-----------------------------------------------------+
| Base Address(24~31) | G | DB | L | A | Limit(16~19) | P | DPL | S | Type | Base Address(16~23)            |
+-----------------------------------------------------+-----------------------------------------------------+
| Base Address(0~15)                                  | Limit(0~15)                                         |
+-----------------------------------------------------+-----------------------------------------------------+
```

- 基地址（base address）：32 位，表示内存段的基地址
- 段界限（limit）：20 位，表示内存段最大偏移值，偏移单位由颗粒度决定，`(limit + 1)*granularity`即内存大小
- 访问类型（access type）：40～47 位，用于控制访问权限
- 标志（flags）：52～55 位，控制粒度，表示 CPU 模式

### 访问类型

- P：存在位（Present bit），1 表示在内存上
- DPL：描述符特权等级（Descriptor privilege level），0～3
- S：描述符类型位（Descriptor type bit），0 表示系统段，1 表示数据段或代码段
- Type：
| X | D/C | R/W | A |
  - X：0，数据段
    - D：Direction bit，0 表示向上增长，1 表示向下增长
    - W：Writable bit，0 表示不可写，1 表示可写
    - A：Accessed bit，1 表示被 CPU 访问过
  - X：1，代码段
    - C：Conforming bit，0 表示只能在 DPL 对应的特权级执行，1 表示可以在
      DPL 对应及以下特权级执行
    - R：Readable bit，0 表示不可读，1 表示可读
    - A：Accessed bit，1 表示被 CPU 访问过

### 标志

- G：Granularity flag，颗粒度，1 表示 4KiB，0 表示 1 B
- DB：Size flag，1 表示 32 位保护模式段，0 表示 16 位
- L：Long-mode flag：1 表示 64 位段
- A：置 0

## 段选择器

与实模式下保存段地址不同，保护模式下段寄存器保存**段选择器**（Segment Selector）。段选择器指明了段描述符在 GDT 中的偏移位置及访问权限。

```txt
+-------------+---------+----------+
| Index(3~15) | Type(2) | RPL(0~1) |
+-------------+---------+----------+
```

- RPL：与 DPL 对应
- Type：0 表示全局描述符，1 表示本地描述符
- Index：段描述符的索引

如`0x08`表示一个索引为 1 的内核态全局描述符。

## gdtr 寄存器

GDT 只是内存中的一个数组，要找到它需要借助`gdtr`寄存器。`gdtr`寄存器保存 GDT 的内存地址以及 GDT 的大小（单位字节）。

```txt
+-----------------+------------+
| Address（16~47) | Size(0~15) |
+-----------------+------------+
```

使用汇编指令`lgdt`和`sgdt`可以将修改和读取`gdtr`寄存器。

```asm
lgdt <address> # 将内存 <address> 的内容加载到 gdtr
sgdt <address> # 将 gdtr 的内容写入到内存 <address>
```

## 参考资料

1. [GDT](https://wiki.osdev.org/GDT)
1. [Segment Selector](https://wiki.osdev.org/Segment_Selector)
3. [Global Descriptor Table](https://en.wikipedia.org/wiki/Global_Descriptor_Table)
1. [Организация памяти](https://habr.com/en/articles/128991/)
