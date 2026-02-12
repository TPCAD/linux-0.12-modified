#include <linuxmodi/asm/io.h>
#include <linuxmodi/asm/system.h>
#include <linuxmodi/tty.h>

// 0x90000 当前光标所在行，0x90001 当前光标所在列
#define ORIG_X (*(unsigned char *)0x90000)
#define ORIG_Y (*(unsigned char *)0x90001)
// 0x90004~0x90005 当前页号
#define ORIG_VIDEO_PAGE (*(unsigned short *)0x90004)
// 0x90006 视频模式，0x03 0x90007 屏幕字符列数，0x50
#define ORIG_VIDEO_MODE ((*(unsigned short *)0x90006) & 0xff)
#define ORIG_VIDEO_COLS (((*(unsigned short *)0x90006) & 0xff00) >> 8)
// 0x9000e 屏幕行数，0x19
#define ORIG_VIDEO_LINES ((*(unsigned short *)0x9000e) & 0xff)
#define ORIG_VIDEO_EGA_AX (*(unsigned short *)0x90008)
#define ORIG_VIDEO_EGA_BX (*(unsigned short *)0x9000a)
#define ORIG_VIDEO_EGA_CX (*(unsigned short *)0x9000c)

#define VIDEO_TYPE_MDA 0x10  /* Monochrome Text Display */
#define VIDEO_TYPE_CGA 0x11  /* CGA Display */
#define VIDEO_TYPE_EGAM 0x20 /* EGA/VGA in Monochrome Mode */
#define VIDEO_TYPE_EGAC 0x21 /* EGA/VGA in Color Mode */

// 系统实际最大虚拟控制台数
int NR_CONSOLES = 0;

static unsigned char video_type;        // Type of display being used
static unsigned long video_num_columns; // 字符列数
static unsigned long video_mem_base;    // 显存起始地址
static unsigned long video_mem_term;    // 显存结束地址
static unsigned long video_size_row;    // 每行字节数，字符列数*2
static unsigned long video_num_lines;   // 行数
static unsigned char video_page;        // Initial video page
static unsigned short video_port_reg;   // Video register select port
static unsigned short video_port_val;   // Video register value port

// vc 是 Virtual Console 的缩写，vc_cons 数组保存了系统所有虚拟控制台的属性
static struct virtual_console {
    unsigned short vc_video_erase_char; // 擦除字符
    unsigned char vc_attr;              // 字符属性
    unsigned char vc_def_attr;          // 默认字符属性
    unsigned long vc_origin;            // 屏幕当前显存起始地址
    unsigned long vc_scr_end;           // 屏幕当前显存结束地址
    unsigned long vc_pos;               // 当前光标的显存地址
    unsigned long vc_x, vc_y;           // 当前光标行、列值
    unsigned long vc_top, vc_bottom;    // 滚动时顶行行号，底行行号
    unsigned long vc_video_mem_start;   // 当前 VC 的显存起始地址
    unsigned long vc_video_mem_end;     // 当前 VC 的显存结束地址
} vc_cons[MAX_CONSOLES];

// 下面是为方便使用 vc_cons 数组而定义的宏
// curcons 代表当前虚拟控制台号
#define origin (vc_cons[currcons].vc_origin)
#define scr_end (vc_cons[currcons].vc_scr_end)
#define pos (vc_cons[currcons].vc_pos)
#define top (vc_cons[currcons].vc_top)
#define bottom (vc_cons[currcons].vc_bottom)
#define x (vc_cons[currcons].vc_x)
#define y (vc_cons[currcons].vc_y)
#define attr (vc_cons[currcons].vc_attr)
#define video_mem_start (vc_cons[currcons].vc_video_mem_start)
#define video_mem_end (vc_cons[currcons].vc_video_mem_end)
#define def_attr (vc_cons[currcons].vc_def_attr)
#define video_erase_char (vc_cons[currcons].vc_video_erase_char)

/**
 *  @brief  更新指定 VC 的光标位置
 *  @param  curcons  VC 号
 *  @param  new_x  新的列号
 *  @param  new_y  新的行号
 *
 *  该函数只是更新内存中的数据，并没有将数据写入端口，改变光标实际位置
 */
static inline void gotoxy(int currcons, int new_x, unsigned int new_y) {
    if (new_x > video_num_lines || new_y >= video_num_columns) {
        return;
    }

    x = new_x;
    y = new_y;
    pos = origin + y * video_size_row + (x << 1);
}

/**
 *  @brief  设置前台 VC 的滚屏起始显存地址
 *  @param  currcons  VC 号
 */
static inline void set_origin(int currcons) {
    if (video_type != VIDEO_TYPE_EGAC && video_type != VIDEO_TYPE_EGAM) {
        return;
    }
    if (currcons != fg_console) {
        return;
    }

    cli();
    outb_p(12, video_port_reg);
    outb_p(0xff & ((origin - video_mem_base) >> 9), video_port_val);
    outb_p(13, video_port_reg);
    outb_p(0xff & ((origin - video_mem_base) >> 1), video_port_val);
    sti();
}

/**
 *  @brief  设置前台 VC 的光标
 *  @param  currcons  VC 号
 */
static inline void set_curcor(int currcons) {
    // blankcount = blankinterval;
    if (currcons != fg_console) {
        return;
    }

    cli();
    outb_p(14, video_port_reg);
    outb_p(0xff & ((pos - video_mem_base) >> 9), video_port_val);
    outb_p(15, video_port_reg);
    outb_p(0xff & ((pos - video_mem_base) >> 1), video_port_val);
    sti();
}

static void scrup(int currcons) {
    if (bottom <= top) {
        return;
    }

    if (video_type != VIDEO_TYPE_EGAC || video_type != VIDEO_TYPE_EGAM) {
        // TODO:
        return;
    }

    if (!top && bottom == video_num_lines) {
        origin += video_size_row;
        pos += video_size_row;
        scr_end += video_size_row;

        if (scr_end > video_mem_term) {
            __asm__("cld\n\t"
                    "rep\n\t"
                    "movsl\n\t"
                    // FIX: 在汇编中直接使用 C 变量
                    "movl video_num_columns,%1\n\t"
                    "rep\n\t"
                    "stosw\n\t" ::"a"(video_erase_char),
                    "c"((video_num_lines - 1) * video_num_columns >> 1),
                    "D"(video_mem_base), "S"(origin)
                    :);
            scr_end -= origin - video_mem_base;
            pos -= origin - video_mem_base;
            origin = video_mem_base;
        } else {
            __asm__("cld\n\t"
                    "rep\n\t"
                    "stosw" ::"a"(video_erase_char),
                    "c"(video_num_columns), "D"(scr_end - video_size_row));
        }
        set_origin(currcons);
    } else {
        __asm__("cld\n\t"
                "rep\n\t"
                "movsl\n\t"
                "movl video_num_columns,%%ecx\n\t"
                "rep\n\t"
                "stosw" ::"a"(video_erase_char),
                "c"((bottom - top - 1) * video_num_columns >> 1),
                "D"(origin + video_size_row * top),
                "S"(origin + video_size_row * (top + 1))
                :);
    }
}

/**
 *  @brief  移动光标位置到下一行
 *  @param  currcons  VC 号
 *
 *  lf 是 line feed（换行）的缩写。换行只是将光标移动到下一行，
 *  但不会移动到行首。
 *
 *  该函数只是更新内存中的数据，并没有将数据写入端口，改变光标实际位置。
 */
static void lf(int currcons) {
    if (y + 1 < bottom) {
        y++;
        pos += video_size_row;
        return;
    }
    scrup(currcons);
}

/**
 *  @brief  移动光标位置到行首
 *  @param  currcons  VC 号
 *
 *  cr 是 carriage return（回车）的缩写。回车只是将光标移动到行首，
 *  但不会移动到下一行。
 *
 *  该函数只是更新内存中的数据，并没有将数据写入端口，改变光标实际位置。
 */
static void cr(int currcons) {
    // 所在列号*2 即是 0 列到所在列对应的内存字节长度
    pos -= x << 1;
    x = 0;
}

/**
 *  @brief  删除光标前一字符并向前移动一列光标
 *  @param  currcons  VC 号
 *
 *  该函数只是更新内存中的数据，并没有将数据写入端口，改变光标实际位置。
 */
static void del(int currcons) {
    if (x) {
        pos -= 2;
        x--;
        *(unsigned short *)pos = video_erase_char;
    }
}

void con_init() {
    char *display_desc = "????";
    char *display_ptr;
    int currcons = 0; // 当前虚拟控制台号
    long video_memory = 0;
    long base, term;

    // 根据保存的硬件参数初始化静态全局变量
    video_num_columns = ORIG_VIDEO_COLS;
    video_size_row = video_num_columns * 2;
    video_num_lines = ORIG_VIDEO_LINES;
    video_page = ORIG_VIDEO_PAGE;
    video_erase_char = 0x0720;

    if (ORIG_VIDEO_MODE == 7) {
        // 显示模式等于 7 表示这是单色显示卡，
        // 这里假定显示卡一定是彩色。
    } else {
        // 显示模式不等于 7，说明这是彩色显示卡，
        // 显存起始地址是 0xb8000，
        // 索引寄存器端口为 0x3d4，
        // 数据寄存器端口为 0x3d5。
        video_mem_base = 0xb8000;
        video_port_reg = 0x3d4;
        video_port_val = 0x3d5;

        // 根据 BL 返回值判断显示卡类型
        if ((ORIG_VIDEO_EGA_BX & 0xff) != 0x10) {
            // EGA 显示卡，有 32KiB 显存
            video_type = VIDEO_TYPE_EGAC;
            video_mem_term = 0xc0000;
            display_desc = "EGAc";
        } else {
            // 否则为 CGA 显示卡
        }
    }

    // 计算实际最大虚拟控制台数量。
    // 以一个屏幕所占字节数（80*25*2）分割显存得到最大虚拟控制台数
    // 最大为 MAX_CONSOLES，最小为 1
    video_memory = video_mem_term - video_mem_base;
    NR_CONSOLES = video_memory / (video_size_row * video_num_lines);
    if (NR_CONSOLES > MAX_CONSOLES) {
        NR_CONSOLES = MAX_CONSOLES;
    }
    if (!NR_CONSOLES) {
        NR_CONSOLES = 1;
    }
    video_memory /= NR_CONSOLES; // 每个虚拟控制台占用的显存字节数

    // 在屏幕右上角打印显示卡类型和当前显示模式
    display_ptr = ((char *)video_mem_base) + video_size_row - 8;
    while (*display_desc) {
        *display_ptr++ = *display_desc++;
        display_ptr++;
    }

    // 初始化 0 号虚拟控制台
    base = video_mem_base;
    term = base + video_memory;
    origin = video_mem_base; // 默认滚屏开始内存地址
    video_mem_start = video_mem_base;
    video_mem_end = video_mem_base + video_memory;
    scr_end = video_mem_start +
              video_num_lines * video_size_row; // 默认滚屏末端内存地址
    top = 0;                                    // 初始滚动时顶行行号
    bottom = video_num_lines;                   // 初始滚动时底行行号
    attr = 0x07;                                // 字符属性，黑底白字
    def_attr = 0x07;                            // 默认字符属性

    gotoxy(currcons, ORIG_X, ORIG_Y); // 更新光标位置

    for (currcons = 1; currcons < NR_CONSOLES; currcons++) {
        vc_cons[currcons] = vc_cons[0];
        origin = (base += video_memory);
        video_mem_start = origin;
        scr_end = origin + video_num_lines * video_size_row;
        video_mem_end = (term += video_memory);
        gotoxy(currcons, 0, 0);
    }

    update_screen();
    // TODO: 开启键盘中断
}

void update_screen() {
    set_origin(fg_console);
    set_curcor(fg_console);
}

void console_print(const char *b) {
    int currcons = fg_console;
    char c = *b++;

    while (c) {
        if (c == 10) {
            cr(currcons);
            lf(currcons);
            continue;
        }
        if (c == 13) {
            cr(currcons);
            continue;
        }
        if (x >= video_num_columns) {
            x -= video_num_columns;
            pos -= video_size_row;
            lf(currcons);
        }
        __asm__("movb %2, %%ah\n\t"
                "movw %%ax, %1\n\t" ::"a"(c),
                "m"(*(short *)pos), "m"(attr));

        pos += 2;
        x++;
        c = *b++;
    }
    set_curcor(currcons);
}
