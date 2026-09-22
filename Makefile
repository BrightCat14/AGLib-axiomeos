CC       ?= cc
MINGW_CC ?= x86_64-w64-mingw32-gcc

CFLAGS   ?= -O2 -Wall -Wextra -Wunused-parameter -Wmisleading-indentation -Wsign-compare

VENDOR = third_party

ZLIB_SRCS = zlib/adler32.c zlib/compress.c zlib/crc32.c zlib/deflate.c \
            zlib/gzclose.c zlib/gzlib.c zlib/gzread.c zlib/gzwrite.c \
            zlib/infback.c zlib/inffast.c zlib/inflate.c zlib/inftrees.c \
            zlib/trees.c zlib/uncompr.c zlib/zutil.c

PNG_SRCS = libpng/png.c libpng/pngerror.c libpng/pngget.c libpng/pngmem.c \
           libpng/pngpread.c libpng/pngread.c libpng/pngrio.c \
           libpng/pngrtran.c libpng/pngrutil.c libpng/pngset.c \
           libpng/pngsimd.c libpng/pngtrans.c libpng/pngwio.c libpng/pngwrite.c \
           libpng/pngwtran.c libpng/pngwutil.c

JPEG_SRCS := $(wildcard $(VENDOR)/libjpeg/*.c)

COMMON = main.c aglib.c $(addprefix $(VENDOR)/,$(ZLIB_SRCS) $(PNG_SRCS)) $(JPEG_SRCS)

X11_CFLAGS := $(shell pkg-config --cflags x11 freetype2)
X11_LIBS   := $(shell pkg-config --libs x11 freetype2) -lm

WIN_LIBS  := -lgdi32
VEND_INC  := -I$(VENDOR)/zlib -I$(VENDOR)/libpng -I$(VENDOR)/libjpeg -I$(VENDOR)/nanosvg/src

# axiomeOS cross toolchain (same as kernel/Makefile)
AXIOME_CC ?= $(HOME)/opt/cross/bin/x86_64-elf-gcc
AXIOME_LD ?= $(HOME)/opt/cross/bin/x86_64-elf-ld
AXIOME_ROOT ?= /home/brightcat/projects/axiomeOS
AXIOME_CFLAGS := -D__AXIOMEOS__ -ffreestanding -nostdlib -nostartfiles -fno-builtin -fno-stack-protector -fPIC -fpie -mcmodel=small -O2 -Wall -Wextra -Wunused-parameter
AXIOME_INC := $(VEND_INC) -I$(AXIOME_ROOT)/kernel/userspace/libc -I$(AXIOME_ROOT)/kernel
AXIOME_BUILD := build/axiome

.PHONY: all clean vend axiome axiome-check

vend:
	@cp -f $(VENDOR)/libpng/pnglibconf.h.prebuilt $(VENDOR)/libpng/pnglibconf.h 2>/dev/null || true

app: $(COMMON) aglib.h vend
	$(CC) $(CFLAGS) -DHAVE_UNISTD_H $(VEND_INC) $(X11_CFLAGS) $(COMMON) -o app $(X11_LIBS)

app.exe: $(COMMON) aglib.h
	$(MINGW_CC) $(CFLAGS) $(VEND_INC) $(COMMON) -o app.exe $(WIN_LIBS)

# ---- axiomeOS targets ----
# `make axiome-check` verifies axiomeOS backend compiles with host toolchain (syntax).
# `make axiome-cross-check` verifies with the freestanding cross compiler (requires setjmp stub).
axiome-check: vend
	@mkdir -p $(AXIOME_BUILD)
	$(CC) -D__AXIOMEOS__ $(CFLAGS) $(VEND_INC) -I$(AXIOME_ROOT)/kernel/userspace/libc -I$(AXIOME_ROOT)/kernel -c aglib.c -o $(AXIOME_BUILD)/aglib.o
	$(CC) -D__AXIOMEOS__ $(CFLAGS) -I$(AXIOME_ROOT)/kernel/userspace/libc -I$(AXIOME_ROOT)/kernel -c main.c -o $(AXIOME_BUILD)/main_axiome.o
	@echo "axiomeOS backend: host-syntax OK ( $(AXIOME_BUILD)/aglib.o )"

axiome-cross-check: vend
	@mkdir -p $(AXIOME_BUILD)
	$(AXIOME_CC) $(AXIOME_CFLAGS) $(AXIOME_INC) -c aglib.c -o $(AXIOME_BUILD)/aglib_cross.o || echo "cross-check: needs setjmp stub (expected on freestanding)"

# Full axiomeOS app as a userspace PIE (needs kernel libc + link.ld + crt0).
# Produces an ELF suitable for /Binaries (add to root_manifest.txt via bin: path).
# Requires that axiomeOS has been built once so build/kernel/libc.sl and crt0 exist.
axiome: vend
	@mkdir -p $(AXIOME_BUILD)
	$(AXIOME_CC) $(AXIOME_CFLAGS) $(AXIOME_INC) -c aglib.c -o $(AXIOME_BUILD)/aglib.o
	$(AXIOME_CC) $(AXIOME_CFLAGS) $(AXIOME_INC) -c main.c -o $(AXIOME_BUILD)/main.o
	$(AXIOME_CC) $(AXIOME_CFLAGS) -c $(AXIOME_ROOT)/kernel/userspace/libc/crt0.c -o $(AXIOME_BUILD)/crt0.o
	$(AXIOME_LD) -pie -T $(AXIOME_ROOT)/kernel/userspace/link.ld --hash-style=sysv -z max-page-size=0x1000 -e _start -o $(AXIOME_BUILD)/agdemo.elf $(AXIOME_BUILD)/crt0.o $(AXIOME_BUILD)/aglib.o $(AXIOME_BUILD)/main.o $(AXIOME_BUILD)/zlib/*.o $(AXIOME_BUILD)/png/*.o $(AXIOME_BUILD)/jpeg/*.o 2>/dev/null || \
	$(AXIOME_LD) -pie -T $(AXIOME_ROOT)/kernel/userspace/link.ld --hash-style=sysv -z max-page-size=0x1000 -e _start -o $(AXIOME_BUILD)/agdemo.elf $(AXIOME_BUILD)/crt0.o $(AXIOME_BUILD)/aglib.o $(AXIOME_BUILD)/main.o $(AXIOME_ROOT)/build/kernel/libc.sl 2>/dev/null || \
	echo "axiome link: expected to need libc.sl — run 'make -C $(AXIOME_ROOT)/kernel' first, then 'make axiome' will link against build/kernel/libc.sl"

clean:
	rm -f app app.exe
	rm -rf build/axiome
