AR:=ar
AS:=as
LD:=ld
LDFLAGS:= -static -m elf_i386
CC:=gcc
CPP:=gcc -E -nostdinc -I../include

CFLAGS:= -m32 # 32 bits program
CFLAGS+= -fno-builtin # no gcc builtin function
CFLAGS+= -nostdinc # no std include file
CFLAGS+= -fno-pic # no position independent code
CFLAGS+= -fno-pie # no position independent executable file
CFLAGS+= -nostdlib # no stdlib
CFLAGS+= -fno-stack-protector
CFLAGS+= -I../include
CFLAGS+= -O0
CFLAGS+= -mno-sse -mno-mmx -mno-sse2

.c.s:
	$(CC) $(CFLAGS) -S -o $*.s $<

.s.o:
	$(AS) -c -o $*.o $<

# .c.o 表示从 %.c -> %.o
.c.o:
	$(CC) $(CFLAGS) -g -c -o $*.o $<

OBJS:= memory.o

.PHONY: clean
clean:
	rm -rf *.o tmp_make

.PHONY: dep
dep:
	sed '/\#\#\# Dependencies/q' < Makefile > tmp_make
	(for i in *.c; do echo -n `echo $$i | sed 's,\.c,\.s,'`" "; \
		$(CPP) -M $$i; done) >> tmp_make
	cp tmp_make Makefile

### Dependencies
