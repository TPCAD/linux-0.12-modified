# ============================ Variable Definition =============================

AS=as
LD=ld
LDFLAGS:=-Ttext 0x0 -static -m elf_i386
CPP=cpp -nostdinc -Iinclude
CC=gcc

CFLAGS:= -m32 # 32 bits program
CFLAGS+= -fno-builtin # no gcc builtin function
CFLAGS+= -nostdinc # no std include file
CFLAGS+= -fno-pic # no position independent code
CFLAGS+= -fno-pie # no position independent executable file
CFLAGS+= -nostdlib # no stdlib
CFLAGS+= -fno-stack-protector
CFLAGS+= -Iinclude
CFLAGS+= -O0
CFLAGS+= -mno-sse -mno-mmx -mno-sse2

ARCHIVES:=kernel/kernel.o
DRIVERS:=kernel/chr_drv/chr_drv.a

# ============================== Compile Command ===============================

.c.s:
	$(CC) $(CFLAGS) -S -o & $*.s $<

.s.o:
	$(AS) -c -o $*.o $<

.c.o:
	$(CC) $(CFLAGS) -g -c -o $*.o $<

boot/bootsect: boot/bootsect.S include/linuxmodi/config.h
	$(CPP) -traditional boot/bootsect.S > boot/bootsect.s
	$(AS) -o boot/bootsect.o boot/bootsect.s
	$(LD) -Ttext 0x0 -s --oformat binary -o $@ boot/bootsect.o

boot/setup: boot/setup.S include/linuxmodi/config.h
	$(CPP) -traditional boot/setup.S > boot/setup.s
	$(AS) -o boot/setup.o boot/setup.s
	$(LD) -Ttext 0x0 -s --oformat binary -o $@ boot/setup.o

boot/head.o: boot/head.S
	$(AS) --32 -c -o $@ $<

kernel/chr_drv/chr_drv.a:
	(cd kernel/chr_drv; make)

kernel/kernel.o:
	(cd kernel; make)

system.o: boot/head.o main.o $(ARCHIVES) $(DRIVERS)
	$(LD) $(LDFLAGS) -e _start -o $@ $^

# 不要使用 ld --oformat 生成二进制文件
system: system.o
	objcopy -O binary $< $@

# =============================== Image Command ================================

image: boot/bootsect boot/setup system
	qemu-img create $@ 1M
	dd bs=512 count=1 conv=notrunc if=boot/bootsect of=$@
	dd bs=512 count=4 seek=1 conv=notrunc if=boot/setup of=$@
	dd bs=512 count=384 seek=5 conv=notrunc if=system of=$@

.PHONY: bochs
bochs: image
	bochs -q -f ../debug/bochsrc
	# bochs -q -f $(ROOT)/debug/bochsnew

QEMU:= qemu-system-i386
QEMU+= -m 32M
QEMU+= -audiodev pa,id=hda
QEMU+= -machine pcspk-audiodev=hda
QEMU+= -drive file=image,if=ide,index=0,media=disk,format=raw
# QEMU+= -drive file=$(BUILD)/slave.img,if=ide,index=1,media=disk,format=raw
# QEMU+= -display curses
# QEMU+= -nographic

QEMU_DEBUG:= -s -S

.PHONY: qemu-gdb
qemu-gdb: image
	$(QEMU) -boot c $(QEMU_DEBUG)
.PHONY: qemu
qemu: image
	$(QEMU) -boot c

# ============================== General Command ===============================

.PHONY: build
build: image

.PHONY: clean
clean:
	rm -rf tmp_make boot/bootsect boot/bootsect.s boot/setup boot/setup.s
	rm -rf *.o boot/*.o system system.map image debug.o
	rm -rf a.out
	(cd kernel; make clean)

.PHONY: dep
dep:
	sed '/\#\#\# Dependencies/q' < Makefile > tmp_make
	(for i in *.c; do $(CPP) -M $$i; done) >> tmp_make
	cp tmp_make Makefile
	(cd kernel; make dep)

### Dependencies
main.o: main.c
