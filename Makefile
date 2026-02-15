ASM = nasm
LD = ld
STRIP = strip

AFLAGS = -f elf64 -O3
LFLAGS = -static -nostdlib -n -N --build-id=none --no-dynamic-linker --no-eh-frame-hdr --no-ld-generated-unwind-info -z norelro --hash-style=sysv --gc-sections
SFLAGS = -s -R .comment -R .gnu.version -R .gnu.version_r -R .gnu.hash -R .note -R .note.gnu.build-id -R .note.ABI-tag -R .eh_frame -R .eh_frame_hdr

CMDS = ls cp mv rm mkdir touch cat dd ps kill nice sh uname uptime free df mount sync reboot echo grep head tail wc clear chmod chown id whoami
BIN = bin

all: $(BIN) $(addprefix $(BIN)/, $(CMDS))

$(BIN):
	mkdir -p $(BIN)

$(BIN)/%: %.asm
	$(ASM) $(AFLAGS) $< -o $@.o
	$(LD) $(LFLAGS) -o $@ $@.o
	$(STRIP) $(SFLAGS) $@
	rm -f $@.o

clean:
	rm -rf $(BIN) *.o

install: all
	for c in $(CMDS); do install -m 755 $(BIN)/$$c /usr/local/bin/asm_$$c; done

uninstall:
	for c in $(CMDS); do rm -f /usr/local/bin/asm_$$c; done

stats:
	@ls -l $(BIN) | awk '{t+=$$5; print $$9 ": " $$5 " bytes"} END {print "total: " t " bytes"}'

test-%: $(BIN)/%
	./$(BIN)/$*
