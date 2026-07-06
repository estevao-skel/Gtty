STRIP := strip
AFLAGS := -f elf64 -O3
LFLAGS := -static -nostdlib -n -N --build-id=none --no-dynamic-linker --no-eh-frame-hdr --no-ld-generated-unwind-info -z norelro --hash-style=sysv --gc-sections
SFLAGS := -s -R .comment -R .gnu.version -R .gnu.version_r -R .gnu.hash -R .note -R .note.gnu.build-id -R .note.ABI-tag -R .eh_frame -R .eh_frame_hdr

all: gatito

gatito: gatito.o
	ld $(LFLAGS) -o gatito gatito.o
	$(STRIP) $(SFLAGS) gatito

gatito.o: gatito.asm
	nasm $(AFLAGS) gatito.asm -o gatito.o

clean:
	rm -f gatito gatito.o

.PHONY: all clean
