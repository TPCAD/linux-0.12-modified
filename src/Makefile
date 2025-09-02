SRC:=.
ROOT:=..
BUILD:=../build

CPP=cpp -nostdinc -Iinclude

$(BUILD)/bootsect: boot/bootsect.S
	@mkdir -p $(@D)
	$(CPP) -traditional boot/bootsect.S > $(BUILD)/bootsect.s
	$(AS) -o $(BUILD)/bootsect.o $(BUILD)/bootsect.s
	$(LD) -s -Ttext=0 --oformat binary -o $@ $(BUILD)/bootsect.o

image: $(BUILD)/bootsect
	qemu-img create $(BUILD)/$@ 1M
	dd bs=512 count=1 conv=notrunc if=$< of=$(BUILD)/$@

run: image
	bochs -f $(ROOT)/debug/bochsrc

build: image

.PHONY: clean
clean:
	rm -rf $(ROOT)/build
