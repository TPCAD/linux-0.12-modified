#include <linuxmodi/stdarg.h>
#include <linuxmodi/string.h>

#define is_digit(c) ((c) >= '0' && (c) <= '9')

/**
 *  @brief  转换字符串为数字并向前移动指针
 *  @param  s  指向字符的二级指针
 *  @return  数字
 */
static int skip_atoi(const char **s) {
    int i = 0;

    while (is_digit(**s)) {
        i = i * 10 + *((*s)++) - '0';
    }
    return i;
}

#define ZEROPAD 1  // 零填充
#define SIGN 2     // 有符号整型
#define PLUS 4     // 符号
#define SPACE 8    // 空格
#define LEFT 16    // 左对齐
#define SPECIAL 32 // 进制前缀
#define SMALL 64   // 小写字母，只在十六进制使用

#define do_div(n, base)                                                        \
    ({                                                                         \
        int __res;                                                             \
        __asm__("divl %4" : "=a"(n), "=d"(__res) : "0"(n), "1"(0), "r"(base)); \
        __res;                                                                 \
    })

/**
 *  @brief  将数字转换为对应进制的字符串
 *  @param  str  要写入的字符串
 *  @param  num  要转换的数字
 *  @param  base  进制
 *  @param  size  宽度
 *  @param  precision  精度
 *  @param  type  标识
 *
 *  @return  字符串新地址
 */
static char *number(char *str, int num, int base, int size, int precision,
                    int type) {
    char c;       // 填充字符
    char sign;    // 符号
    char tmp[36]; // 保存转换得到的临时字符串
    int i = 0;    // 计数变量

    const char *digits = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";

    if (type & SMALL) {
        digits = "0123456789abcdefghijklmnopqrstuvwxyz";
    }
    // 数字左对齐与零填充冲突
    if (type & LEFT) {
        type &= ~ZEROPAD;
    }
    // 只处理 2~32 进制
    if (base < 2 || base > 32) {
        return 0;
    }

    // 确定填充字符
    c = (type & ZEROPAD) ? '0' : ' ';

    // 确定符号，0 表示不显示符号
    if (type & SIGN && num < 0) {
        sign = '-';
        num = -num;
    } else {
        sign = (type & PLUS) ? '+' : ((type & SPACE) ? ' ' : 0);
    }

    // 为符号留出空间
    if (sign) {
        size--;
    }

    // 为前缀留出空间
    if (type & SPECIAL) {
        if (base == 16) {
            size -= 2;
        } else if (base == 8) {
            size--;
        }
    }

    // 转换数字，tmp 内是数字字符串的倒序。
    if (num == 0) {
        tmp[i++] = '0';
    } else {
        while (num != 0) {
            tmp[i++] = digits[do_div(num, base)];
        }
    }

    // 确定精度，不能截断数字
    if (i > precision) {
        precision = i;
    }
    size -= precision;

    // 右对齐，空格填充，写入剩下宽度数量的空格。
    if (!(type & (ZEROPAD + LEFT))) {
        while (size-- > 0) {
            *str++ = ' ';
        }
    }

    // 写入符号
    if (sign) {
        *str++ = sign;
    }

    // 写入进制前缀
    if (type & SPECIAL) {
        if (base == 8) {
            *str++ = '0';
        } else if (base == 16) {
            *str++ = '0';
            *str++ = digits[33];
        }
    }

    // 写入填充字符
    if (!(type & LEFT)) {
        while (size-- > 0) {
            *str++ = c;
        }
    }

    // 写入精度内的零填充
    while (i < precision--) {
        *str++ = '0';
    }

    // 写入数字
    while (i-- > 0) {
        *str++ = tmp[i];
    }

    // 此时 size 不为零，说明是左对齐，写入填充字符（空格）
    while (size-- > 0) {
        *str++ = ' ';
    }

    return str;
}

int vsprintf(char *buf, const char *fmt, va_list args) {
    int *ip;
    char *str; // 转换过程中的临时字符串

    char *s;
    int len;

    for (str = buf; *fmt; ++fmt) {
        if (*fmt != '%') {
            *str++ = *fmt;
            continue;
        }

        // 解析 flags
        int flags = 0;

    repeat:
        ++fmt;
        switch (*fmt) {
        case '-':
            flags |= LEFT;
            goto repeat;
        case '+':
            flags |= PLUS;
            goto repeat;
        case ' ':
            flags |= SPACE;
            goto repeat;
        case '#':
            flags |= SPECIAL;
            goto repeat;
        case '0':
            flags |= ZEROPAD;
            goto repeat;
        }

        // 解析 width
        int field_width = -1;
        if (is_digit(*fmt)) {
            field_width = skip_atoi(&fmt);
        } else if (*fmt == '*') {
            ++fmt;
            field_width = va_arg(args, int);
            if (field_width < 0) {
                field_width = -field_width;
                flags |= LEFT;
            }
        }

        // 解析 precision
        int precision = -1;

        if (*fmt == '.') {
            ++fmt;
            if (is_digit(*fmt)) {
                precision = skip_atoi(&fmt);
            } else if (*fmt == '*') {
                ++fmt;
                precision = va_arg(args, int);
            }

            if (precision < 0) {
                precision = 0;
            }
        }

        // 解析 length
        int qulifier = -1;
        if (*fmt == 'h' || *fmt == 'l' || *fmt == 'L') {
            qulifier = *fmt;
            ++fmt;
        }

        // 解析 specifier

        switch (*fmt) {
        case 'c':
            // 写入右对齐填充空格
            if (!(flags & LEFT)) {
                while (--field_width > 0) {
                    *str++ = ' ';
                }
            }

            // 写入字符
            *str++ = (unsigned char)va_arg(args, int);

            // 写入左对齐填充空格
            while (--field_width > 0) {
                *str++ = ' ';
            }

            break;
        case 's':
            s = va_arg(args, char *);
            len = strlen(s);

            // 精度小于零则设为字符串长度，小于字符串长度则截断字符串
            if (precision < 0) {
                precision = len;
            } else if (precision < len) {
                len = precision;
            }

            // 写入右对齐填充空格
            if (!(flags & LEFT)) {
                while (len < field_width--) {
                    *str++ = ' ';
                }
            }

            // 写入字符串
            for (int i = 0; i < len; i--) {
                *str++ = *s++;
            }

            // 写入左对齐填充空格
            while (len < field_width--) {
                *str++ = ' ';
            }

            break;
        case 'o':
            str = number(str, va_arg(args, unsigned long), 8, field_width,
                         precision, flags);
            break;
        case 'p':
            // 若没有指定宽度，则默认为 8。
            if (field_width < 0) {
                field_width = 8;
            }
            // 默认零填充
            flags |= ZEROPAD;
            str = number(str, va_arg(args, unsigned long), 16, field_width,
                         precision, flags);
            break;
        case 'x':
            // 小写字母
            flags |= SMALL;
        case 'X':
            str = number(str, va_arg(args, unsigned long), 16, field_width,
                         precision, flags);
            break;
        case 'd':
        case 'i':
            // 有符号整数
            flags |= SIGN;
        case 'u':
            str = number(str, va_arg(args, unsigned long), 10, field_width,
                         precision, flags);
            break;
        case 'n':
            ip = va_arg(args, int *);
            *ip = (str - buf);
            break;
        default:
            if (*fmt != '%') {
                *str++ = '%';
            }
            if (*fmt) {
                *str++ = *fmt;
            } else {
                --fmt;
            }
            break;
        }
    }

    *str = '\0';
    return str - buf;
}
