# 准备工作

## 项目结构

```txt
src
├── boot
├── include
├── kernel
├── lib
└── Makefile
```

## 内核启动流程

1. BIOS 加载 MBR 到内存`0x7c00`
2. Bootloader
  - bootsect.S 移动自身到内存`0x90000`
  - bootsect.S 加载 setup.S 到内存`0x90200`
  - bootsect.S 加载内核到内存`0x10000`之后
  - 跳转 setup.S 执行
  - setup.S 保存获取硬件参数到内存`0x90000`
  - setup.S 移动内核到内存`0x0`
  - 进入保护模式
    - 加载 GDT
    - 开启 A20 线
    - 初始化 8259A
    - 开启保护模式
    - 跳转内核执行（head.S）
3. 内核初始化前（head.S）
  - 重新加载 GDT
  - 初始化 IDT
  - 初始化页表，开启分页
  - 跳转 main.c 执行
4. 内核初始化
