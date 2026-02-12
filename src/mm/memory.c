#include <linuxmodi/mm.h>

unsigned long HIGH_MEMORY = 0;

unsigned char mem_map[PAGING_PAGES] = {
    0,
};

void mem_init(long start_mem, long end_mem) {
    int i = 0;
    HIGH_MEMORY = end_mem;
    // 全部标记为已占用
    for (i = 0; i < PAGING_PAGES; i++) {
        mem_map[i] = USED;
    }

    // (0x400000 - 0x100000) >> 12 = 0x400
    i = MAP_NR(start_mem); // 用户内存开始的索引

    // 除前 4MiB 外，剩余内存页标记为空闲
    end_mem -= start_mem;
    end_mem >>= 12; // 计数器
    while (end_mem-- > 0) {
        mem_map[i++] = 0;
    }
}
