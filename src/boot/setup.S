#include "linuxmodi/config.h"

.equ INITSEG, DEF_INITSEG # bootsect.S 原来所在的内存地址
.equ SETUPSEG, DEF_SETUPSEG # setup.S 所在的内存地址
.equ SYSSEG, DEF_SYSSEG # system 模块所在的内存地址

.code16
.global _start
_start:
    movw $INITSEG, %ax # 将 ds 修改为 0x9000
    movw %ax, %ds

    /* 使用 BIOS 第 0x15 号中断获取扩展内存大小并保存在 0x90002
     *
     * int 0x15 参数如下所示：
     * ah=0x88 获取扩展内存大小服务
     * 若成功，ax 从 0x100000 开始的连续内存大小（KB）
     * 若出错则 CF 置位，ah 输出错误码
    */
    movw $0x8800, %ax
    int $0x15
    movw %ax, (2)

    /* 使用 BIOS 第 0x10 号中断获取当前光标位置并保存到 0x90000 */
    movb $0x03, %ah
    xorb %bh, %bh
    int $0x10
    movw %dx, (0)

    /* 使用 BIOS 第 0x10 号中断获取当前显示模式并保存到 0x90004 */
    movb $0x0f, %ah
    int $0x10
    movw %bx, (4)
    movw %ax, (6)

    /* 检查显示方式（EGA/VGA）并获取相关参数并保存到 0x90008 */
    movb $0x12, %ah
    movb $0x10, %bl
    int $0x10
    movw %ax, (8)
    movw %bx, (10)
    movw %cx, (12)

    # 这里原本需要比较 bl 返回值是否等于 0x10 以确定是否是 VGA 显示卡，
    # 若不是则跳转检测显示卡。
    # 但 Bochs 和 QEMU 都默认使用 VGA，因此这里不再做比较并删除检测显示卡相关代码
    # 同时硬编码显示卡的行数为 0x19，列数为 0x50
    movw $0x5019, %ax
    movw %ax, (14)

    /* 获取第一块硬盘（disk0）的信息并保存到 0x90080 */
    movw $0x0, %ax
    movw %ax, %ds
    lds (0x4 * 0x41), %si
    movw $INITSEG, %ax
    movw %ax, %es
    movw $0x0080, %di
    movw $0x10, %cx
    rep movsb

    /* 获取第二块硬盘（disk1）的信息并保存到 0x90090 */
    movw $0x0, %ax
    movw %ax, %ds
    lds (0x4 * 0x46), %si
    movw $INITSEG, %ax
    movw %ax, %es
    movw $0x0090, %di
    movw $0x10, %cx
    rep movsb

    /* 检查是否有第二块硬盘 */
    movw $0x1500, %ax
    movb $0x81, %dl
    int $0x13
    jc no_disk1
    cmp $3, %ah
    je is_disk1

no_disk1:
    /* 没有第二块硬盘则清空刚才写入 0x90090 的内容 */
    movw $INITSEG, %ax
    movw %ax, %es
    movw $0x0090, %di
    movw $0x10, %cx
    movw $0x0, %ax
    rep stosb

is_disk1:
    /* 有第二块硬盘则继续执行 */

    cli

    /* 将 system 模块从 0x10000 移动到 0x0，即整体向前移动 0x10000 字节 */
    movw $0x0, %ax
    cld
do_move:
    movw %ax, %es        # 目标段地址
    addw $0x1000, %ax    # 每轮大循环复制 0x10000 字节
    cmpw $0x9000, %ax    # 判断条件
    jz end_move
    movw %ax, %ds        # 源段地址
    subw %di, %di
    subw %si, %si
    movw $0x8000, %cx    # 每轮小循环复制 2 字节，循环 0x8000 次
    rep movsw
    jmp do_move

end_move:
    movw $SETUPSEG, %ax
    movw %ax, %ds
    lgdt [gdt_48]
    lidt [idt_48]

    # 开启 A20 线
    in $0x92, %al
    orb $2, %al
    out %al, $0x92

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

    # 进入保护模式
    movl %cr0, %eax
    orb $1, %al
    movl %eax, %cr0

    # 进入保护模式后应立即进行一次远跳转以确保不会执行实模式指令
    # 直接跳转到 head.S
    ljmp $code_selector, $0x0

    # 不应该执行到这里
    hlt

# 段选择子
# | 3~15 | 2 | 0~1 |
#   ^      ^    ^
#   | 索引 |    | RPL
#          |
#          | 0 表示全局描述符，1 表示局部描述符
.equ code_selector, (1 << 3) # 0b0000_0000_0000_1000
.equ data_selector, (2 << 3) # 0b0000_0000_0001_0000

# 当时 linus 只有 16 MB 的内存
.equ memory_base, 0 # 内存起始地址
# 内存段界限
.equ memory_limit, ((1024*1024*16) / (1024*4)) - 1

gdt:
    .word 0,0,0,0    # 第一项必须是 0
    # .quad 0x00c09a0000000fff
    # .quad 0x00c0920000000fff
# 代码段
gdt_code:
    # 段界限前 16 位
    .word memory_limit & 0xffff
    # 段基地址前 16 位
    .word memory_base & 0xffff
    # 段基地址 16～23 位
    .byte (memory_base >> 16) & 0xff
    # access type.
    # P: 1, on memory
    # DPL: 00, ring 0
    # S: 1, code or data segment
    # X: 1, code segment
    # C: 0, no conforming
    # R: 1, readable
    # A: 0, no accessed
    .byte 0b10011010
    # G: 1, 4K granularity
    # DB: 1, 32 bits
    # L: 0, not long-mode
    # AV: 0
    # 段界限后 4 位
    .byte 0b11000000 | ((memory_limit >> 16) & 0xf)
    # 段基地址 24～31 位
    .byte (memory_base >> 24) & 0xff
# 数据段
gdt_data:
    .word memory_limit & 0xffff
    .word memory_base & 0xffff
    .byte (memory_base >> 16) & 0xff
    # access type.
    # P: 1, on memory
    # DPL: 00, ring 0
    # S: 1, code or data segment
    # X: 0, data segment
    # D: 0, direction, grown up
    # W: 1, writable
    # A: 0, no accessed
    .byte 0b10010010
    .byte 0b11000000 | ((memory_limit >> 16) & 0xf)
    .byte (memory_base >> 24) & 0xff
gdt_end:

gdt_48:
    .word (gdt_end - gdt) + 1
    .word 0x200+gdt, 0x9

# CPU 要求进入保护模式前设置 IDT，这里定义一个长度为 0 的空表，
# 进入内核后再重新设置 IDT
idt_48:
    .word 0
    .long 0
