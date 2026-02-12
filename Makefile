ROOT:=.
SRC:=$(ROOT)/src
BUILD:=$(ROOT)/build

.PHONY: clean
clean:
	rm -rf $(ROOT)/build

include src/Makefile
