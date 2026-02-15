NASM = nasm
LD = ld
STRIP = strip

NASMFLAGS = -f elf64 -O3

LDFLAGS = -static \
          -nostdlib \
          -n \
          -N \
          --build-id=none \
          --no-dynamic-linker \
          --no-eh-frame-hdr \
          --no-ld-generated-unwind-info \
          -z norelro \
          --hash-style=sysv \
          --gc-sections

STRIPFLAGS = -s \
             -R .comment \
             -R .gnu.version \
             -R .gnu.version_r \
             -R .gnu.hash \
             -R .note \
             -R .note.gnu.build-id \
             -R .note.ABI-tag \
             -R .eh_frame \
             -R .eh_frame_hdr

SOURCE = gatito.asm
TARGET = gatito
BINDIR = bin

.PHONY: all clean install uninstall test stats run

all: $(BINDIR) $(BINDIR)/$(TARGET)
	@echo ""
	@echo "════════════════════════════════════════"
	@echo "✅ Gatito compilado com sucesso! 🐱"
	@echo "════════════════════════════════════════"
	@$(MAKE) -s stats

$(BINDIR):
	@mkdir -p $(BINDIR)

$(BINDIR)/$(TARGET): $(SOURCE)
	@printf "⚙️  Compilando $(TARGET) ... "
	@$(NASM) $(NASMFLAGS) $< -o $(BINDIR)/$(TARGET).o 2>/dev/null || (echo "❌ FALHOU" && exit 1)
	@$(LD) $(LDFLAGS) -o $@ $(BINDIR)/$(TARGET).o 2>/dev/null || (echo "❌ FALHOU" && exit 1)
	@$(STRIP) $(STRIPFLAGS) $@ 2>/dev/null || true
	@chmod +x $@
	@rm -f $(BINDIR)/$(TARGET).o
	@SIZE=$$(stat -c %s $@ 2>/dev/null || stat -f %z $@); \
	printf "✅ %'6d bytes\n" $$SIZE

clean:
	@echo "🧹 Limpando..."
	@rm -rf $(BINDIR) *.o
	@echo "✅ Limpeza concluída"

install: all
	@echo "📦 Instalando em /usr/local/bin..."
	@install -m 755 $(BINDIR)/$(TARGET) /usr/local/bin/$(TARGET)
	@echo "✅ $(TARGET) instalado"

uninstall:
	@echo "🗑️  Desinstalando..."
	@rm -f /usr/local/bin/$(TARGET)
	@echo "✅ $(TARGET) removido"

stats:
	@echo ""
	@echo "📊 ESTATÍSTICAS DO BINÁRIO:"
	@echo "════════════════════════════════════════"
	@if [ -f $(BINDIR)/$(TARGET) ]; then \
		SIZE=$$(stat -c %s $(BINDIR)/$(TARGET) 2>/dev/null || stat -f %z $(BINDIR)/$(TARGET)); \
		printf "  Tamanho    : %'6d bytes\n" $$SIZE; \
		printf "  Executável : $(BINDIR)/$(TARGET)\n"; \
	fi
	@echo "════════════════════════════════════════"

run: all
	@echo "🚀 Iniciando gatito..."
	@$(BINDIR)/$(TARGET)

test: all
	@echo "🧪 Testando $(TARGET)..."
	@if [ -x $(BINDIR)/$(TARGET) ]; then \
		echo "✅ Binário executável"; \
		file $(BINDIR)/$(TARGET); \
	else \
		echo "❌ Binário não encontrado ou não executável"; \
	fi

info:
	@echo "════════════════════════════════════════"
	@echo "  GATITO 🐱 - CAT EM ASSEMBLY X86-64"
	@echo "════════════════════════════════════════"
	@echo ""
	@echo "Características:"
	@echo "  • Clone do comando cat"
	@echo "  • Exibe conteúdo de arquivos"
	@echo "  • Binário ultra-compacto"
	@echo "  • Extremamente rápido"
	@echo ""
	@echo "Uso:"
	@echo "  make          - Compila o gatito"
	@echo "  make run      - Compila e executa"
	@echo "  make clean    - Remove binários"
	@echo "  make install  - Instala no sistema"
	@echo "  make test     - Testa o binário"
	@echo "  make stats    - Mostra estatísticas"
	@echo "════════════════════════════════════════"
