#ifndef _TTY_H
#define _TTY_H

#define MAX_CONSOLES 8

extern int fg_console;

void con_init();

void update_screen();

#endif
