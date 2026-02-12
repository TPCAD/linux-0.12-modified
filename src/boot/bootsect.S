#include "linuxmodi/config.h"

.equ SETUPLEN, 4 # setup.S 程序所占扇区数
.equ BOOTSEG, 0x07C0 # MBR 最初被加载到的内存位置
.equ INITSEG, DEF_INITSEG # 将 MBR 移动到该地址
.equ SETUPSEG, DEF_SETUPSEG # 加载 setup.S 到该内存地址
.equ SYSSEG, DEF_SYSSEG # 加载 system 模块到该内存地址
.equ SYSSIZE, DEF_SYSSIZE # system 模块的大小
.equ SYSEND, SYSSEG+SYSSIZE # system 模块结束段地址

.code16
.global _start
_start:
    /* 将 bootsect.S 拷贝到 0x90000 */
    movw $BOOTSEG, %ax          # 将 ds 寄存器设为 0x07c0，用作源地址
    movw %ax, %ds
    movw $INITSEG, %ax          # 将 es 寄存器设为 0x9000，用作目的地址
    movw %ax, %es
    movw $256, %cx              # 将 cx 寄存器设为 256，用作循环计数
    subw %si, %si               # 清空 si，di 寄存器
    subw %di, %di
    cld                         # 清空 Directive Flag，表示字符串操作时地址自增
    rep movsw                   # 每次从 ds:si 拷贝两字节到 es:si，重复 cx 次

    ljmp $INITSEG, $go          # 跳转到 0x90000 执行代码

go:
    /* 设置寄存器。其中 es 已经是 0x9000。ljmp 指令使得 cs 也变为 0x9000。
     * 将 ds，ss 设为 0x9000，di，sp 设为 0xff00。
     **/
    movw %cs, %ax               # 将 ds 设为 0x9000
    movw %ax, %ds
    movw %ax, %ss               # 将 ss 设为 0x9000

    /* 栈顶指针默认向低地址增长，且不能覆盖程序代码。在 0x90000～0x90200 已经
     * 存放了 bootsect.S，而随后还要存放 setup.S（0x200 * 4），因此栈顶指针应该
     * 远大于 0x90000 + 0x200 + 0x200 * 4。Linux 0.12 中这个值是 0x9ff00。
     * */
    movw $0xff00, %sp

load_setup:
    /* 使用 BIOS 第 0x13 号中断从硬盘第 2 个扇区读取 setup.S 到内存 0x90200， 共 4 个扇区。
     * 若出现错误重置硬盘并重试。
     *
     * int 0x13 参数如下所示：
     * ah=2 读扇区服务，al 读取的扇区数，
     * ch 磁道号低 8 位，cl 扇区号（0～5）和磁道号高 2 位（6～7）
     * dh 磁头号，dl 驱动器号
     * es:bx 缓冲区地址
     * 若出错则 CF 置位，ah 输出错误码
     **/
    movw $0x0080, %dx                # 磁头号 0，驱动器号 0x80
    movw $0x0002, %cx                # 磁道号 0，扇区号 2
    movw $0x0200 + SETUPLEN, %ax     # 读扇区服务，扇区数
    movw $0x200, %bx                 # 缓冲区偏移地址
    int $0x13
    jnc ok_load_setup

    /* 使用 0x13 号中断重置硬盘，ah=0 复位功能号，dl=0x80 第一块硬盘 */
    movb $0x80, %dl
    xorb %ah, %ah
    int $0x13
    /* 重新读取 setup.S */
    jmp load_setup

ok_load_setup:
    movw $load_setup_msg, %si    # 打印成功信息
    call print_str

    movw $0x0, %ax                # 置 es 为 0
    movw %ax, %es

    /* 使用 BIOS 第 0x13 号中断从硬盘第 6 个扇区开始，读取 system 模块到内存 0x10000，共 1024 个扇区。
     * 若出现错误重置硬盘并重试。
     *
     * 每次中断读取 0x80（128）个扇区，循环 8 次。
     **/
load_system:
    movw $0x0, %bx              # 缓冲区偏移地址
    movw $0x0080, %dx           # 磁头号 0，驱动器号 0x80
    movw $0x0006, %cx           # 磁道号 0，扇区号 6

do_read:
    movw %es, %ax               # 每次从 es 获取上次的源地址
    addw $0x1000, %ax           # 每轮大循环复制 0x10000 字节
    movw %ax, %es
retry:                          # 发生错误时的重试入口
    cmpw $SYSEND, %ax           # 结束条件
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
    movw $INITSEG, %ax                # 恢复段地址 0x9000
    movw %ax, %es
    movw $load_system_msg, %si    # 打印成功信息
    call print_str

    ljmp $SETUPSEG, $0        # 跳转 setup.S

/* 打印函数 */
print_str:
    movb $0xe, %ah
    .Lprint_char:
        lodsb
        cmpb $0, %al
        je .Lprint_done
        int $0x10
        jmp .Lprint_char
    .Lprint_done:
        ret

load_setup_msg: .asciz "Setup module has been loaded\n\r"
load_system_msg: .asciz "System module has been loaded\n\r"

# 剩余字节填充为 0
.fill 510-(.-_start), 1, 0

boot_flag:
    .word 0xAA55

# vim: ft=asm
