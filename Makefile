CLANG      ?= clang
BPFTOOL    ?= bpftool
CC         ?= gcc

ARCH       := $(shell uname -m | sed 's/x86_64/x86/' | sed 's/aarch64/arm64/')
KERNEL_VER := $(shell uname -r)

LIBBPF_SRC := ./libbpf-1.3.0/src
LIBBPF_OBJ := $(LIBBPF_SRC)/libbpf.a

BPF_CFLAGS := -g -O2 -target bpf -D__TARGET_ARCH_$(ARCH) \
              -I/usr/include/$(shell uname -m)-linux-gnu \
              -I$(LIBBPF_SRC)

CFLAGS     := -g -O2 -Wall -I$(LIBBPF_SRC)

.PHONY: all clean run deps libbpf

all: af_alg_block

# fetch libbpf source from apt and build static library
libbpf:
	apt-get source libbpf
	$(MAKE) -C libbpf-1.3.0/src BUILD_STATIC_ONLY=1
	ln -sf . libbpf-1.3.0/src/bpf

# generate vmlinux.h from running kernel's BTF
vmlinux.h:
	$(BPFTOOL) btf dump file /sys/kernel/btf/vmlinux format c > vmlinux.h

# compile eBPF program to object file
af_alg_block.bpf.o: af_alg_block.bpf.c vmlinux.h
	$(CLANG) $(BPF_CFLAGS) -c $< -o $@

# generate libbpf skeleton from object file
af_alg_block.bpf.skel.h: af_alg_block.bpf.o
	$(BPFTOOL) gen skeleton $< > $@

# compile userspace loader — statically link libbpf
af_alg_block: af_alg_block.c af_alg_block.bpf.skel.h $(LIBBPF_OBJ)
	$(CC) $(CFLAGS) -static $< -o $@ $(LIBBPF_OBJ) -lelf -lz -lzstd

clean:
	rm -f vmlinux.h af_alg_block.bpf.o af_alg_block.bpf.skel.h af_alg_block

# install build dependencies (Ubuntu 24.04 build machine)
deps:
	sudo apt install -y clang llvm libelf-dev zlib1g-dev libzstd-dev dpkg-dev musl-tools \
	                    linux-tools-$(KERNEL_VER) linux-tools-common

run: all
	sudo ./af_alg_block