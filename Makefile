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

.PHONY: all clean vend

all: app app.exe

vend:
	@cp -f $(VENDOR)/libpng/pnglibconf.h.prebuilt $(VENDOR)/libpng/pnglibconf.h 2>/dev/null || true

app: $(COMMON) aglib.h vend
	$(CC) $(CFLAGS) -DHAVE_UNISTD_H $(VEND_INC) $(X11_CFLAGS) $(COMMON) -o app $(X11_LIBS)

app.exe: $(COMMON) aglib.h
	$(MINGW_CC) $(CFLAGS) $(VEND_INC) $(COMMON) -o app.exe $(WIN_LIBS)

clean:
	rm -f app app.exe
