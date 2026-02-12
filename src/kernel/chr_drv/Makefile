AR:=ar
AS:=as
CC:=gcc
# CFLAGS:= -m32 -I../../include -nostdinc -Wall -fomit-frame-pointer -fno-pic -g
CPP:=gcc -E -nostdinc -I../../include

CFLAGS:= -m32 # 32 bits program
CFLAGS+= -fno-builtin # no gcc builtin function
CFLAGS+= -nostdinc # no std include file
CFLAGS+= -fno-pic # no position independent code
CFLAGS+= -fno-pie # no position independent executable file
CFLAGS+= -nostdlib # no stdlib
CFLAGS+= -fno-stack-protector
CFLAGS+= -I../../include
CFLAGS+= -O0
CFLAGS+= -mno-sse -mno-mmx -mno-sse2

.c.s:
	$(CC) $(CFLAGS) -S -o $*.s $<

.s.o:
	$(AS) -c -o $*.o $<

# .c.o 表示从 %.c -> %.o
.c.o:
	$(CC) $(CFLAGS) -g -c -o $*.o $<

OBJS:= tty_io.o console.o

chr_drv.a: $(OBJS)
	ar rcs $@ $^

.PHONY: clean
clean:
	rm -rf *.o *.a tmp_make

.PHONY: dep
dep:
	sed '/\#\#\# Dependencies/q' < Makefile > tmp_make
	(for i in *.c; do echo -n `echo $$i | sed 's,\.c,\.s,'`" "; \
		$(CPP) -M $$i; done) >> tmp_make
	cp tmp_make Makefile

### Dependencies:
console.s console.o: console.c ../../include/linuxmodi/asm/io.h \
 ../../include/linuxmodi/asm/system.h ../../include/linuxmodi/tty.h
tty_io.s tty_io.o: tty_io.c ../../include/linuxmodi/tty.h
