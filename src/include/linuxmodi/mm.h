#ifndef _MM_H
#define _MM_H

#define PAGE_SIZE 4096

#define LOW_MEM 0x100000                   // 前 1MiB 内存
#define PAGING_MEMORY (15 * 1024 * 1024)   // 分页内存 15MiB
#define PAGING_PAGES (PAGING_MEMORY >> 12) // 分页内存的物理页数
// 内存地址所在页的页面号（从 1MiB 开始，用于 mem_map）
#define MAP_NR(addr) (((addr) - LOW_MEM) >> 12)
#define USED 100 // 页面也被占用

#endif
