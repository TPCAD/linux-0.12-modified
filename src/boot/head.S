.code32
.global _start, pg_dir, idt, gdt, tmp_floppy_area
pg_dir:
_start:
    # 进入保护模式后重新加载代码段和栈
    movw $data_selector, %ax
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %fs
    movw %ax, %gs
    movw %ax, %ss
    xchgw %bx, %bx
    movl $stack_start, %eax
    movl %eax, %esp
    # FIX: lss not work
    # 如果以 elf_x86_64 为目标平台 bochs 会出现错误：
    # bx_dbg_read_linear: physical memory read error (phy=0x000100000000, lin=0x0000000100000000)
    # 如果以 i386 为目标平台，虽然不会出错，但 lss 不起作用
    # lss stack_start, %esp

    # 重新设置 GDT 和 IDT
    call setup_idt
    call setup_gdt

    # 加载 GDT 后重新加载代码段和栈
    movl $data_selector, %eax
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %fs
    movw %ax, %gs
    xchgw %bx, %bx
    movw %ax, %ss
    movl $stack_start, %eax
    movl %eax, %esp
    # lss stack_start, %esp

    # 检查 A20 线是否开启
    xorl %eax, %eax
1:  incl %eax
    movl %eax, 0x000000
    cmpl %eax, 0x100000
    je 1b

    jmp after_page_tables

/* 将所有中断处理程序设置为 ignore_int */
setup_idt:
    leal ignore_int, %edx
    movl $0x00080000, %eax
    movw %dx, %ax
    movw $0x8e00, %dx

    lea idt, %edi
    movl $256, %ecx
sidt_loop:
    movl %eax, (%edi)
    movl %edx, 4(%edi)
    addl $8, %edi
    dec %ecx
    jne sidt_loop

    lidt idt_descr
    ret

setup_gdt:
    lgdt gdt_descr
    ret

.org 0x1000
pg0:

.org 0x2000
pg1:

.org 0x3000
pg2:

.org 0x4000
pg3:

.org 0x5000

tmp_floppy_area:
    .fill 1024, 1, 0

after_page_tables:
    pushl $0
    pushl $0
    pushl $0
    pushl $L6
    pushl $main
    jmp setup_paging
L6:
    jmp L6

.align 4
setup_paging:
    # 清空前 20 KiB
    movl $1024*5, %ecx
    xorl %eax, %eax
    xorl %edi, %edi
    cld
    rep stosl

    # 设置页目录
    # 页目录的第一项为页目录自身，随后三项是页表
    movl $pg0 + 7, pg_dir
    movl $pg1 + 7, pg_dir + 4
    movl $pg2 + 7, pg_dir + 8
    movl $pg3 + 7, pg_dir + 12

    # 设置页表
    # 从最后一项开始设置，每次减 0x1000（4K）
    movl $pg3 + 4092, %edi
    movl $0xfff007, %eax
    std
1:
    stosl
    subl $0x1000, %eax
    jge 1b

    # 加载页目录并开启分页
    xorl %eax, %eax
    movl %eax, %cr3
    movl %cr0, %eax
    orl $0x80000000, %eax
    movl %eax, %cr0

    # 此时栈顶是 main，因此完成分页后直接跳转 main
    ret

int_msg:
    .asciz "Unknown interrupt\n\r"

ignore_int:
    pushl %eax
    pushl %ecx
    pushl %edx
    pushw %ds
    pushw %es
    pushw %fs
    movl $data_selector, %eax
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %fs

    # TODO: 调用 printk
    movl $0xb8096, %edi
    movb $'I', %al
    movb $0x0c, %ah
    movw %ax, (%edi)

    popw %fs
    popw %es
    popw %ds
    popl %edx
    popl %ecx
    popl %eax
    iret

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

idt:
    .fill 256, 8, 0

.align 4
.word 0
idt_descr:
    .word 256 * 8 - 1
    .long idt

.align 4
.word 0
gdt_descr:
    .word 256 * 8 - 1
    .long gdt
