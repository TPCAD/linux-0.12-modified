# GNU Assembly

## 实模式寻址

早期 8086 CPU 的寄存器是 16 位的，最大寻址为 \\(2^{16}=64 KB\\)。为了扩大寻址范围，Intel 将地址线增加到 20 位，并引入分段式内存管理。简单来说，内存地址由都是 16 位的**段地址**和**偏移地址**组合而成，其公式为：

\\[(SegmentAddress \ll 4) + OffsetAddress \\]

此时的最大寻址为 \\(2^{20}=1 MB\\)

## AT&T 汇编语法

### 格式

```txt
mnemonic source, destination
```

```asm
movb $0x12, %al
```

表示将值 `0x12` 写入到寄存器 `al`。

### 前缀

寄存器必须加上前缀 `%`，如 `%al`，`%ax`，`%si`。数字常量必须加上前缀 `$`，如 `$0x12`，`$12`，但也不是所有数字都需要加上前缀。

```asm
# 只需在操作数整体前加上前缀即可
movb $0x12 + 0x22 - 10, %al
```

### 后缀

指令通常带有指明操作数大小的后缀。

- `b`：byte（8 bit）
- `s`：single（32 bit 浮点型）
- `w`：word（16 bit）
- `l`：long（32 bit 整型或 64 bit 浮点型）
- `q`：quad（64 bit）
- `t`：ten bytes（80 bit 浮点型）

如果不带后缀，那么编译器会根据目标寄存器进行推断。

### 标签

标签的作用相当于 C 中的函数名或变量名。

```asm
# 定义一个名为 `message` 的变量
message:
    .asciz "Hello World!"

# 定义名为 `_add` 的函数
_add:
    movl 4(%esp), %eax
    addl 8(%esp), %eax
    ret

# 调用函数
call _add
```

标签的本质是地址。`call _add` 其实就是跳转到 `_add` 所代表的地址。

~如果想获得标签的地址，可以使用 `$`。如 `movl $_add, %eax` 表示将 `_add` 所代表的地址加载到 `%eax`。这类似 C 中的「取地址」操作，`&_add`。~

不同汇编指令对待标签的方式也不相同，比如 `jmp _add` 将 `_add` 当成地址，而 `inc _add` 可能会将 `_add` 解引用，使它所指向的值自增。

### 常用寄存器

#### 通用寄存器（General-Purpose Register）

通用寄存器可用于几乎所有用途，并不局限于下面提到的场景。

- `ax`：Accumulator register，累加寄存器，常用于算术运算
- `bx`：Base register，基址寄存器，常用于段模式寻址
- `cx`：Counter register，计数寄存器，常用于循环计数
- `sp`：Stack Pointer register，栈指针寄存器，指向栈顶
- `bp`：Stack Base Pointer register，栈底指针寄存器，指向栈底
- `di`：Destination Index register，目的索引寄存器，指向流操作中目的地址
- `si`：Source Index register，源索引寄存器，指向流操作中源地址
- `dx`：Data register，数据寄存器，常用于算术运算和 IO 操作

上面的顺序也是通用寄存器的入栈顺序。

在 16 位模式下，`si` 的默认段寄存器是 `ds`，`di` 则是 `es`。

#### 段寄存器（Segment Register）

- `ss`：Stack Segment，存放栈的起始地址
- `cs`：Code Segment，存放代码段的起始地址
- `ds`：Data Segment，存放数据段的起始地址
- `es`：Extra Segment，存放额外代码段的起始地址
- `fs`：F Segment，存放额外代码段的起始地址
- `gs`：G Segment，存放额外代码段的起始地址

#### EFLAGS 寄存器

TODO:

### 地址操作数

```txt
# AT&T
segment:displacement(base register, index register, scale factor)
# Intel
segment:[base register + displacement + index register * scale factor]
```

AT&T 的地址操作数标志是 `()`，当指令遇到地址操作数时会自动解引用。

`displacement`，`base register` 和 `index register` 均可省略（至少有一个），且当省略 `index register` 时，`scale factor` 也必须被省略。省略 `segment` 时，默认使用 `ds`，当 `base register` 是 `bp` 或 `sp` 时默认使用 `ss`。

### 常用指令

#### jmp

```asm
jmp loc
```

Jump，无条件跳转执行指定地址的代码，其实质是修改 `ip` 寄存器。

#### ljmp

```asm
ljmp seg, loc
```

Long Jump，无条件跳转执行指定地址的代码，同时修改 `cs` 和 `ip` 寄存器。

#### lods

Load String，从内存地址 `ds:si` 中加载一个单位的数据到合适的寄存器（al、ax）。

加载完成后 `si` 会根据 EFLAGS 的 DF 位加 1 或减 1。如果 DF 为 0 则加 1，为 1 则减 1。DF 位可以使用 `cld` 置为 0，使用 `std` 置为 1。

```asm
    movw $msg, %si
    movb $0xe, %ah
print_char:
    lodsb
    cmpb $0, %al
    je done
    int $0x10
    jmp print_char
done:
    hlt
```

#### movs

Move String，从 `ds:si` 拷贝一个单位数据到 `es:di`。

拷贝完成后 `si` 和 `di` 会根据 EFLAGS 的 DF 位加 1 或减 1。如果 DF 为 0 则加 1，为 1 则减 1。DF 位可以使用 `cld` 置为 0，使用 `std` 置为 1。

```asm
.code16
    movw $0x07c0, %ax         # 将 ds 寄存器设为 0x07c0，用作源地址
    movw %ax, %ds
    movw $0x9000, %ax         # 将 es 寄存器设为 0x9000，用作目的地址
    movw %ax, %es
    movw $256, %cx            # 将 cx 寄存器设为 256，用作循环计数
    subw %si, %si             # 清空 si，di 寄存器
    subw %di, %di
    cld                       # 清空 Directive Flag，表示字符串操作时地址自增
    rep movsw                 # 每次从 ds:si 拷贝两字节到 es:si，重复 cx 次
```

#### stos

从`ax`拷贝一个单位数据到`es:di`

拷贝完成后 `si` 和 `di` 会根据 EFLAGS 的 DF 位加 1 或减 1。如果 DF 为 0 则加 1，为 1 则减 1。DF 位可以使用 `cld` 置为 0，使用 `std` 置为 1。

### 汇编器指令

汇编器指令是用于提示编译器编译的指令，不是汇编指令。汇编器指令以 `.` 开头，并且区分大小写，通常都是小写。

#### .

指代当前位置。

```asm
.fill 510-(.-_start), 1, 0
```

#### .ascii/.asciz

```asm
.ascii "String1", "String2", ...
```

连续存储一系列没有结束符的字符串。

```asm
.asciz "String1", "String2", ...
```

连续存储一系列有结束符的字符串。不按照逗号进行分隔的字符串会被合并到一起。

#### .globl/.global

```asm
.globl symbol
.global symbol
```

使 `symbol` 对于 ld 可见。

#### .fill

```asm
.fill repeat, size, value
.fill repeat
```

填充 `repeat` 次 `size` 字节的 `value`。`size` 最大为 8 字节。如果只有 `repeat` 一个参数，则 `size` 为 1，`value` 默认为 0。

#### Data Types

| 预处理器指令 | 字节数 | 含义        |
| ------------ | ------ | ----------- |
| .byte        | 1      | 预留 1 字节 |
| .word        | 2      | 预留 2 字节 |
| .long        | 4      | 预留 4 字节 |
| .quad        | 8      | 预留 8 字节 |
| .short       | 2      | 预留 2 字节 |
| .int         | 4      | 预留 4 字节 |

### 逻辑运算符

GNU AS 的 `|` 和 `&` 是同一优先级的运算符，按从左到右的顺序运算。而 NASM 的 `&` 优先级要高于 `|`。

## 内联汇编

`asm`关键字允许将汇编指令嵌入到 C 代码中。GNU 提供了两种内联汇编语法语句。

`asm`关键字是 GUN 提供的扩展，当没有 GNU 扩展时，可以使用`__asm__`代替。

### 基础内联汇编

```language
asm asm-qualifiers ( AssemblerInstructions )
```

#### 修饰符

**volatile**

对基础内联汇编来说，`volatile`修饰符没有作用，因为所有基础内联汇编都是隐式`volatile`。

**inline**

内联汇编的大小会是最小（见 [Size of an asm](https://gcc.gnu.org/onlinedocs/gcc-15.2.0/gcc/Size-of-an-asm.html)）。

### 扩展内联汇编

使用扩展内联汇编可以读写 C 变量。

```language
asm asm-qualifiers ( AssemblerTemplate 
                 : OutputOperands 
                 [ : InputOperands
                 [ : Clobbers ] ])

asm asm-qualifiers ( AssemblerTemplate
                      : OutputOperands
                      : InputOperands
                      : Clobbers
                      : GotoLabels)
```

#### 汇编模板

要嵌入的汇编指令。使用`%%`生成一个`%`。如，想要表示`%ax`，那么在模板中应该写成`%%ax`。

#### 操作数

输出操作数指明哪些 C 变量会被内联汇编语句修改。输入操作数指明执行前用到哪些 C 变量。操作数由`,`分隔，每个操作数具有如下格式：

```language
[ [asmSymbolicName] ] constraint (cvariablename)
```

**asmSymbolicName**

操作数在模板中对应的汇编符号。

```c
asm("movl %[src], %[dst]": [dst] "=r" (out) : [src] "r" (in) );
```

除了指定符号名外，还可以对操作数编号。编号不区分输入输出操作数，所有操作数按出现的先后顺序从 0 开始编号。

```c
asm("movl %1, %0" : "=r"(out) : "r"(in))
```

**constraint**

一个用于约束编译器的字符串，告诉编译器可以使用什么寄存器或内存来暂存输出结果或保存输入变量。输出约束必须以`=`或`+`开始。输出操作数在前缀之后必须有一个或多个额外约束。

通用约束：

| 约束 | 描述 |
| -------------- | --------------- |
| = | 只读操作数 |
| + | 可读可写操作数 |
| m | 内存 |
| r | 通用寄存器 |

x86 常用约束：

| 约束 | 描述 |
| -------------- | --------------- |
| a | eax 寄存器 |
| b | ebx 寄存器 |
| c | ecx 寄存器 |
| d | edx 寄存器 |
| S | esi 寄存器 |
| D | edi 寄存器 |

**cvariablename**

对应的 C 表达式，通常是变量名，输出操作数必须是左值表达式。`()`是必须的。

#### Clobber

Clobber 用于告诉编译器汇编代码除了使用操作数列出的寄存器外还**可能**会用到哪些寄存器。Clobber 列出的寄存器不能与操作数列出的寄存器重合。

## 命令行参数

### -g

增加调试信息。

#### --32

编译 32 位程序。

## 参考资料

1. [AS Document](https://sourceware.org/binutils/docs/as/index.html)
2. [x86-gnu-assembly-primer.md](https://gist.github.com/AVGP/85037b51856dc7ebc0127a63d6a601fa)
3. [What is the purpose of GNU assembler directive .code16?](https://stackoverflow.com/questions/60025609/what-is-the-purpose-of-gnu-assembler-directive-code16)
