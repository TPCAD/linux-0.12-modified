/* 构建启动镜像时，bootsect.S 会被写入到 bootimage 的第一个扇区，也就是 MBR。
 * 加电自检后 BIOS 会加载 MBR 也就是 bootsect.S 到内存 0x7c00。
 *
 * bootsect.S 的功能是将自己拷贝到内存 0x90000 处，并从软盘加载 setup.S 到内存
 * 0x902000（紧随 bootsect.S 之后），加载 system 模块（内核）到内存 0x10000。
 */

/* 导入 C 头文件应使用 #include，并使用 `cpp` 或 `gcc -E` 进行预处理。
 * 而 .include 只能导入汇编代码。
 **/
#include "linux/config.h"

.equ SETUPLEN, 4 # setup.S 程序所占扇区数
.equ BOOTSEG, 0x07C0 # MBR 最初被加载到的内存位置
.equ INITSEG, DEF_INITSEG # 将 MBR 移动到该地址
.equ SETUPSEG, DEF_SETUPSEG # 加载 setup.S 到该内存地址
.equ SYSSEG, DEF_SYSSEG # 加载 system 模块到该内存地址
.equ SYSSIZE, DEF_SYSSIZE # system 模块的大小
.equ ENDSEG, SYSSEG + SYSSIZE # system 模块结束地址

# ROOT_DEV 和 SWAP_DEV 由 build.c 确定
.equ ROOT_DEV, 0
.equ SWAP_DEV, 0

.code16
.global _start
_start:
    xchgw %bx, %bx
    # 将 bootsect.S 移动到 0x90000
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
    xchgw %bx, %bx
    /* 设置寄存器。其中 es 已经是 0x9000。
     * 将 ds，ss 设为 0x9000，di，sp 设为 0xfef4。
     **/
    movw %cs, %ax               # 将 ds 设为 0x9000
    movw %ax, %ds
    movw %ax, %ss               # 将 ss 设为 0x9000

    /* 栈顶指针默认向低地址增长，且不能覆盖程序代码。在 0x90000～0x92000 已经
     * 存放了 bootsect.S，而随后还要存放 setup.S（0x200 * 4），因此栈顶指针应该
     * 远大于 0x90000 + 0x200 + 0x200 * 4。Linux 0.12 中这个值是 0x9ff00。
     *
     * 接下来要在栈中存放一个软盘参数表（12 B），因此要留出这一部分的内存。
     * */
    movw $0xfef4, %di      # 0x9ff00 - 12 = 0x9fef4
    movw %di, %sp

    xchgw %bx, %bx
    /* 一些 BIOS 读多扇区时不能超过默认最大扇区数（通常是 7 扇区），为此需要修改
     * 默认最大扇区数。这个数据可以通过 BIOS 中断向量表找到。
     *
     * BIOS 中断向量表是一组函数指针，每一项占 4 字节，共 256 项。其中第 0x1e 项
     * 是一个指向 DPT（Diskette Parameter Table），软盘参数表的指针。
     */
    movw %cx, %fs          # 清空 fs（因为之前循环操作，此时 cx 是 0）
    movw $0x78, %bx        # 0x1e * 4 = 0x78，DPT 指针的内存地址
    pushw %ds
    ldsw %fs:(%bx), %si    # 将 *fs:bx（DPT指针）拷贝到 ds:si 作为源地址？
    movb $6, %cl           # 拷贝 12 字节，每次 2 字节
    pushw %di
    # cld                  # 已经在前面设置了
    rep movsw              # 拷贝 DPT 到 es:di
    popw %di
    popw %ds
    movb $18, 4(%di)       # 修改 *es:(di+4) 为 18（修改默认最大扇区数）
    movw %di, %fs:(%bx)    # 修改 *fs:bx，使 0x1e 号向量指向新的参数表
    movw %es, %fs:2(%bx)

    movw %cs, %ax          # 恢复 fs，gs 寄存器为 0x9000
    movw %ax, %fs
    movw %ax, %gs

    xchgw %bx, %bx
    # 使用 0x13 号中断复位软盘驱动，ah=0 复位功能号，dl=0 第一块软盘
    xor %ah, %ah
    xor %dl, %dl
    int $0x13
    xchgw %bx, %bx

load_setup:
    /* 使用 BIOS 第 0x13 号中断从软盘第 2 个扇区读取 setup.S 到内存 0x90200，
     * 共 4 个扇区。若出现错误则显示软盘出错扇区位置并复位驱动器重试。
     *
     * int 0x13 参数如下所示：
     * ah=2 读扇区服务，al 读取的扇区数，
     * ch 磁道号低 8 位，cl 扇区号（0～5）和磁道号高 2 位（6～7）
     * dh 磁头号，dl 驱动器号
     * es:bx 缓冲区地址
     * 若出错则 CF 置位，ah 输出错误码
     **/
    xorw %dx, %dx                    # 磁头号 0，驱动器号 0
    movw $0x0002, %cx                # 磁道号 0，扇区号 2
    movw $0x0200 + SETUPLEN, %ax    # 读扇区服务，扇区数
    int $0x13
    jnc ok_load_setup

    /* 读硬盘失败，打印错误码 */
    pushw %ax         # 错误码入栈
    call print_nl     # 回车，换行
    movw %sp, %bp     # 使用 bp 传参
    call print_hex    # 以十六进制打印错误码
    popw %ax          # 出栈

    /* 使用 0x13 号中断复位软盘驱动，ah=0 复位功能号，dl=0 第一块软盘 */
    xorb %dl, %dl
    xorb %ah, %ah
    int $0x13

    /* 重新加载 setup.S */
    jmp load_setup

ok_load_setup:
    /* 使用 BIOS 第 0x13 号中断获取软盘驱动参数，以获取每磁道扇区数，
     * 并保存在 sectors 处。
     *
     * int 0x13 参数如下所示：
     * ah=8 读驱动参数，dl 驱动器号
     * 返回信息：
     * ah 错误码，若出错则 CF 置位，
     * bl 驱动器类型（只有 AT/PS2 软盘），
     * ch 最大磁道号低 8 位，cl 最大扇区号（0～5）和最大磁道号高 2 位（6～7），
     * dh 最大磁头号，dl 驱动器数量，
     * es:di 软盘驱动参数表地址
     **/
    xorb %dl, %dl
    movb $0x08, %ah
    int $0x13
 
    /* 保存最大扇区号到 sectors。对于软盘来说，磁道最大不超过 256，ch 已经足够
     * 表示它，因此 cl 的高 2 位必定是 0。将 ch 清空后，cx 就是最大扇区号。
     **/
    xorb %ch, %ch         # 清空 ch 使得 cx 就是最大扇区号
    movw $sectors, %cx    # 保存最大扇区号
    movw $INITSEG, %ax    # 恢复刚刚被修改的 es
    movw %ax, %es

    /* 使用 BIOS 第 0x10 号中断打印字符串「Loading\n\r」
     *
     * int 0x10，读光标位置
     * ah=0x03，读光标位置服务号，bh 页号
     * 返回信息：
     * ch 扫描开始线，cl 扫描结束线，
     * dh 行号(0x00 顶端)，dl 列号(0x00 最左边)
     *
     * int 0x10，写字符串
     * ah=0x13，写字符串服务号
     * al 放置光标的方式及规定属性。0x01 表示使用 bl 中的属性值，
     * 光标停在字符串结尾处。
     * bh 页号，bl 字符属性，dh 行号，dl 列号，cx 显示的字符串字符数。
     * es:bp 指向要显示的字符串起始位置处。
     **/
    movb $0x03, %ah       # 服务号
    xorb %bh, %bh         # 页号 0
    int $0x10

    movw $9, %cx          # 共写入 9 个字符
    movw $0x0007, %bx     # 页号 0，attribute 7
    movw $msg1, %bp       # 写入字符串的地址
    movw $0x1301, %ax     # 服务号，写入模式
    int $0x10

    /* 加载 system 模块到内存 0x10000（64 KB） 处*/
    movw $SYSSEG, %ax
    movw %ax, %es
    call read_it
    call kill_monitor
    call print_nl

    /* 检查要使用的根文件系统设备*/
    # 检查 root_dev 是否已定义
    movw $root_dev, %ax
    or %ax, %ax
    jne root_defined

    /* root_dev 未定义，通过判断最大扇区数确定软盘类型
     *
     * linux 0.12 的设备号命名方式如下：
     * 设备号 = 主设备号 * 256 + 次设备号
     * 软盘的主设备号为 2，次设备号 = type * 4 + nr
     * 其中 type 是软驱类型，1.2MB 软驱为 2，1.44 MB 软驱为 7
     * nr 为 0～3 对应软驱 A、B、C、D
     */
    movw $sectors, %bx
    movw $0x0208, %ax    # 1.2MB A 驱动器设备号
    cmp $15, %bx         # 1.2MB 软盘最大扇区数为 15
    je root_defined
    movw $0x021c, %ax    # 1.44MB A 驱动器设备号
    cmp $18, %bx         # 1.44MB 软盘最大扇区数为 18
    je root_defined

undef_root:
    jmp undef_root

root_defined:
    /* 保存根文件系统设备号到 ax 以作为参数传递给 setup.S */
    movw $root_dev, %ax

    ljmp $0, $SETUPSEG

/* read_it 是读取 system 模块的主要函数。在 bootimage 中，system 模块紧随 
 * setup.S，并且长度不确定。因此在读取时需要考虑磁道变换和段溢出的情况。
 *
 * sread 为当前磁道已读取扇区数。1 + SETUPLEN 表示已读取引导扇区和 setup.S 的 
 * 4 个扇区。head 为当前磁头号，track 为当前磁道号。
 **/
sread: .word 1 + SETUPLEN
head: .word 0
track: .word 0

read_it:
    /* 检查 es 是否是 0x1000 */
    movw %es, %ax
    test $0xfff, %ax
die:
    jne die             # 死循环

    xor %bx, %bx        # bx 记录当前段内偏移，通过段内偏移判断是否段溢出
rp_read:
    movw %es, %ax
    cmp $ENDSEG, %ax    # 检查是否已加载全部数据（这里假设系统大小一定大于一个段）
    jb ok1_read         # 未加载完则跳转 ok1_read
    ret                 # 已加载完则结束
ok1_read:
    /* 计算本次读取扇区数。每次读取都尽量读取一个段或一个磁道。 */
    movw $sectors, %ax
    subw $sread, %ax    # 计算当前磁道剩余扇区数
    movw %ax, %cx
    shlw $9, %cx        # 左移 9 位即乘 512，得到当前磁道剩余字节数
    addw %bx, %cx       # 再加上当前段内偏移得到最终段内偏移
    jnc ok2_read        # 未超出 64 KB，跳转 ok2_read
    je ok2_read

    /* 超出 64 KB，计算最大可读取扇区数 */
    xorw %ax, %ax
    sub %bx, %ax        # 0 - 当前段内偏移 = 可用段内偏移
    shrw $9, %ax        # 可用偏移除以 512 得到最大可读取扇区
ok2_read:
    /* 读取扇区，并更新已读取扇区数，若已读完则更换磁头或磁道，未读完则继续读取 */
    call read_track
    movw %ax, %cx       # 保存本次操作已读取扇区数到 cx
    addw $sread, %ax    # 保存当前磁道已读取扇区数
    cmp $sectors, %ax   # 还有未读完扇区，跳转 ok3_read
    jne ok3_read

    /* 当前磁道当前磁头已读取（软盘只有一个盘片，一个盘片有两面），则读取下一磁
     * 头，若已读取，则读下一磁道。
     **/
    movw $1, %ax
    subw $head, %ax    # 判断是否是磁道的第二磁头
    jne ok4_read       # 是第一个磁头，继续读第二磁头
    incw track         # 两个磁头都已读完，读下一磁道
ok4_read:
    movw %ax, head    # 保存当前磁头号
    xorw %ax, %ax
ok3_read:
    movw %ax, sread   # 保存当前磁道已读扇区数
    shlw $9, %cx
    addw %cx, %bx      # 计算当前段内偏移
    jnc rp_read        # 未超过 64 KB，继续读

    /* 超过 64 KB，调整段基地址 */
    movw %es, %ax
    addb $0x10, %ah
    movw %ax, %es
    xorw %bx, %bx      # 清空段内偏移
    jmp rp_read
read_track:
    pusha               # 入栈所有寄存器
    /* 打印「.」*/
    pusha               # 为 0x10 中断入栈所有寄存器
    movw $0xe2e, %ax    # 服务号和 '.'
    movw $7, %bx
    int $0x10
    popa                # 恢复寄存器

    /* 读取扇区
     * int 0x13 参数如下所示：
     * ah=2 读扇区服务，al 读取的扇区数，
     * ch 磁道号低 8 位，cl 扇区号（0～5）和磁道号高 2 位（6～7）
     * dh 磁头号，dl 驱动器号
     * es:bx 缓冲区地址
     * 若出错则 CF 置位，ah 输出错误码
     **/
    movw $track, %dx
    movw $sread, %cx
    incw %cx             # cl 扇区号
    movb %dl, %ch        # ch 磁道号低 8 位
    movw $head, %dx
    movb %dl, %dh        # dh 磁头号
    andw $0x0100, %dx    # dl 驱动器号
    movb $2, %ah         # ah 功能号

    pushw %dx            # 保存可能的错误信息
    pushw %cx
    pushw %bx
    pushw %ax

    int $0x13
    jc bad_rt            # 出错，跳转 bad_rt
    addw $8, %sp         # 未出错，出栈错误信息
    popa
    ret

bad_rt:
    pushw %ax            # 打印错误码
    call print_all

    xorb %ah, %ah        # 复位驱动器
    xorb %dl, %dl
    int $0x13

    addw $10, %sp        # 出栈错误信息
    popa
    jmp read_track       # 重试

/* 打印栈内 ax，bx，cx，dx 寄存器值及错误码，此时的栈如下所示：
 * ret <- sp
 * error
 * ax
 * bx
 * cx
 * dx
 **/
print_all:
    movw $5, %cx
    movw %sp, %bp    # 保存栈顶指针
print_loop:
    pushw %cx
    call print_nl
    jae no_reg         # CF 为 0 则不显示寄存器名

    movw $0xe05 + 0x41 - 1, %ax
    subb %cl, %al      # 0x45 - cl，打印「@/A/B/C/D」
    int $0x10

    movb $0x58, %al    # 打印「X」
    int $0x10

    movb $0x3a, %al    # 打印「:」
    int $0x10
no_reg:
    addw $2, %bp       # 下一个寄存器值
    call print_hex
    popw %cx
    loop print_loop
    ret
print_nl:
    /* 使用 BIOS 第 0x10 号中断打印回车和换行
     * int 0x10 参数如下所示：
     * ah 0xe TTY 输出服务，al 输出字符，
     * bh 页号，bl 颜色属性
     **/
    movw $0x0e0d, %ax    # 服务号，回车
    int $0x10
    movb $0xa, %al       # 换行
    int $0x10
    ret
print_hex:
    /* 使用 BIOS 第 0x10 号中断以十六进制打印 ss:bp 指向的字（2 字节，4 字符）
     * int 0x10 参数如下所示：
     * ah 0xe TTY 输出服务，al 输出字符，
     * bh 页号，bl 颜色属性
     **/
    movw $4, %cx
    movw (%bp), %dx
print_digit:
    rolw $4, %dx                    # 左旋 4 位是原本高 4 位移动到低 4 位
    movb $0xe, %ah
    movb %dl, %al
    andb $0xf, %al                  # 将高 4 位置零，只使用低 4 位

    addb $0x30, %al                 # 将数字转换为 ASCII 字符
    cmp $0x39, %al                  # 大于 0x39 则为 A～F，需要处理
    jbe good_digit
    addb $0x41 - 0x30 - 0xa, %al    # 将数字转换为 A～F
good_digit:
    int $0x10
    loop print_digit
    ret

/* 关闭软盘驱动的马达 */
kill_monitor:
    pushw %dx
    movw $0x3f2, %dx
    xorb %al, %al
    outb %al, %dx
    popw %ax
    ret

sectors: .word 0

msg1: .ascii "Loading\n\r"

.org 506
swap_dev: .word SWAP_DEV
root_dev: .word ROOT_DEV

# MBR 签名 0x55AA
boot_flag:
    .word 0xAA55

# vim: ft=asm
