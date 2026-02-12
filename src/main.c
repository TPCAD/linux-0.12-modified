#define __LIBRARY__

#define EXT_MEM_K (*(unsigned short *)0x90002) // 扩展内存，单位 KiB

extern void tty_init();
extern void mem_init(long, long);

extern int printk(const char *, ...);

static long memory_end = 0;        // 扩展内存结束地址
static long buffer_memory_end = 0; // 缓冲内存结束地址
static long main_memory_start = 0; // 主内存开始地址，缓冲内存之后，用于用户程序

int main() {
    memory_end = (1 << 20) + (EXT_MEM_K << 10);
    memory_end &= 0xfffff000; // 4K 对齐

    // 最多支持 16MiB
    if (memory_end > 16 * 1024 * 1024) {
        memory_end = 16 * 1024 * 1024;
    }
    // 缓冲内存大小
    if (memory_end > 12 * 1024 * 1024) {
        buffer_memory_end = 4 * 1024 * 1024;
    } else if (memory_end > 6 * 1024 * 1024) {
        buffer_memory_end = 2 * 1024 * 1024;
    } else {
        buffer_memory_end = 1 * 1024 * 1024;
    }
    // 主内存
    main_memory_start = buffer_memory_end;

    // 初始化内存管理
    mem_init(main_memory_start, memory_end);

    tty_init();
    __asm__ __volatile__("loop:\n\r"
                         "jmp loop" ::);
}
