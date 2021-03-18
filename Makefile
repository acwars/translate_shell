NAME     = "translate_shell"
COMMAND  = translate
BUILDDIR ?= build
MANDIR   = man

TARGET   ?= bash
PREFIX   ?= /usr/local

.PHONY: default clean build grip check install uninstall

default: build

clean:
	@gawk -f build.awk clean

build:
	@gawk -f build.awk build -target=$(TARGET)

grip:
	@gawk -f build.awk readme && grip

install: build
	install $(BUILDDIR)/$(COMMAND) $(DESTDIR)$(PREFIX)/bin/$(COMMAND) &&\
	install $(MANDIR)/$(COMMAND).1 $(DESTDIR)$(PREFIX)/share/man/man1/$(COMMAND).1 &&\
	echo "[OK] $(NAME) installed."

uninstall:
	@rm $(DESTDIR)$(PREFIX)/bin/$(COMMAND) $(DESTDIR)$(PREFIX)/share/man/man1/$(COMMAND).1 &&\
	echo "[OK] $(NAME) uninstalled."
